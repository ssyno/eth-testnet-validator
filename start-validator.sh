#!/bin/bash
#
# start-validator.sh - Import validator keys and start the validator
#
# Usage:
#   ./start-validator.sh <keys_directory>
#
# The keys directory must contain:
#   - keystore-*.json  : Encrypted validator keystores
#   - password.txt     : Password for the keystores
#
set -e

NAMESPACE="${ETH_NAMESPACE:-eth-validator}"
KEYS_DIR="$1"

# Validate arguments
if [ -z "$KEYS_DIR" ]; then
    echo "Usage: $0 <keys_directory>"
    echo ""
    echo "Example:"
    echo "  $0 ./validator_keys"
    exit 1
fi

if [ ! -d "$KEYS_DIR" ]; then
    echo "Error: Directory not found: $KEYS_DIR"
    exit 1
fi

if [ ! -f "$KEYS_DIR/password.txt" ]; then
    echo "Error: Missing password file: $KEYS_DIR/password.txt"
    echo ""
    echo "Create it with:"
    echo "  echo 'your-password' > $KEYS_DIR/password.txt"
    exit 1
fi

# Check for keystore files
KEYSTORES=$(find "$KEYS_DIR" -name "keystore-*.json" 2>/dev/null | wc -l)
if [ "$KEYSTORES" -eq 0 ]; then
    echo "Error: No keystore files found in $KEYS_DIR"
    exit 1
fi

echo "=== Importing Validator Keys ==="
echo ""
echo "Found $KEYSTORES keystore(s)"

# Create temporary directory for packaging
TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

# Package keys as tarball (Lighthouse expects this format)
echo "Packaging keys..."
tar -czf "$TMP/keys.tar.gz" -C "$KEYS_DIR" .
cp "$KEYS_DIR/password.txt" "$TMP/password.txt"

# Create/update Kubernetes secret
echo "Creating Kubernetes secret..."
kubectl delete secret eth-validator-keys -n "$NAMESPACE" 2>/dev/null || true
kubectl create secret generic eth-validator-keys -n "$NAMESPACE" \
    --from-file=validator_keys.tar.gz="$TMP/keys.tar.gz" \
    --from-file=validator_password.txt="$TMP/password.txt"

# Restart validator to pick up new keys
echo "Restarting validator..."
kubectl rollout restart statefulset \
    -l app.kubernetes.io/component=validator \
    -n "$NAMESPACE"

# Wait for rollout
kubectl rollout status statefulset \
    -l app.kubernetes.io/component=validator \
    -n "$NAMESPACE" \
    --timeout=120s

echo ""
echo "=== Validator Started ==="
echo ""
echo "Next step: Check health"
echo "  ./check-health.sh"
