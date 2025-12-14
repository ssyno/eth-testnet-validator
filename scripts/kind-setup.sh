#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${KIND_CLUSTER_NAME:-eth-validator}"

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "Cluster '$CLUSTER_NAME' already exists"
    kubectl config use-context "kind-$CLUSTER_NAME" &>/dev/null || true
    exit 0
fi

echo "Creating Kind cluster '$CLUSTER_NAME'..."

cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30303
        hostPort: 30303
        protocol: TCP
      - containerPort: 30303
        hostPort: 30303
        protocol: UDP
      - containerPort: 9000
        hostPort: 9000
        protocol: TCP
      - containerPort: 9000
        hostPort: 9000
        protocol: UDP
EOF

kubectl config use-context "kind-$CLUSTER_NAME"
echo "Cluster ready"
