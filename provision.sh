#!/bin/bash
#
# provision.sh - Deploy Ethereum validator infrastructure
#
# Supports two modes:
#   Local:  Uses KIND (Kubernetes in Docker) for development
#   Cloud:  Uses existing kubectl context (DigitalOcean, GKE, EKS, etc.)
#
# Usage:
#   ./provision.sh              # Local KIND cluster
#   ./provision.sh --cloud      # Cloud Kubernetes cluster
#
set -e

NAMESPACE="${ETH_NAMESPACE:-eth-validator}"
VALUES_FILE="values-dev.yaml"
CLOUD_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --cloud)
            CLOUD_MODE=true
            VALUES_FILE="values-cloud.yaml"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--cloud]"
            exit 1
            ;;
    esac
done

echo "=== Ethereum Validator Provisioning ==="
echo ""

# Step 1: Setup Kubernetes cluster
if [ "$CLOUD_MODE" = true ]; then
    echo "Mode: Cloud (using current kubectl context)"
    CONTEXT=$(kubectl config current-context 2>/dev/null || true)
    if [ -z "$CONTEXT" ]; then
        echo "Error: No kubectl context configured"
        exit 1
    fi
    echo "Context: $CONTEXT"
else
    echo "Mode: Local (KIND)"
    ./scripts/kind-setup.sh
fi
echo ""

# Step 2: Create namespace
echo "Creating namespace: $NAMESPACE"
kubectl get namespace "$NAMESPACE" &>/dev/null || kubectl create namespace "$NAMESPACE"

# Step 3: Create JWT secret for execution/consensus authentication
if ! kubectl get secret eth-jwt -n "$NAMESPACE" &>/dev/null; then
    echo "Creating JWT secret..."
    kubectl create secret generic eth-jwt -n "$NAMESPACE" \
        --from-literal=jwtsecret="$(openssl rand -hex 32)"
else
    echo "JWT secret already exists"
fi

# Step 4: Deploy Helm chart
echo ""
echo "Deploying Helm chart with $VALUES_FILE..."
helm upgrade --install eth-validator ./charts/eth-validator \
    --namespace "$NAMESPACE" \
    --values "$VALUES_FILE" \
    --wait --timeout 5m

echo ""
echo "=== Provisioning Complete ==="
echo ""
echo "Next step: Import validator keys"
echo "  ./start-validator.sh ./validator_keys"
