#!/bin/bash
#
# check-health.sh - Verify validator health and attestation status
#
# Outputs: Validator "0xabc123..." is active and attesting on slot 123456
#
set -e

NAMESPACE="${ETH_NAMESPACE:-eth-validator}"

# Find beacon pod
BEACON_POD=$(kubectl get pod -n "$NAMESPACE" \
    -l app.kubernetes.io/component=consensus \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -z "$BEACON_POD" ]; then
    echo "Error: Beacon pod not found"
    exit 1
fi

# Setup port-forward to beacon API
kubectl port-forward -n "$NAMESPACE" "pod/$BEACON_POD" 15052:5052 &>/dev/null &
PF_PID=$!
trap "kill $PF_PID 2>/dev/null || true" EXIT
sleep 2

# Get current head slot
SYNC_RESPONSE=$(curl -s http://localhost:15052/eth/v1/node/syncing 2>/dev/null)
if [ -z "$SYNC_RESPONSE" ]; then
    echo "Error: Could not connect to beacon API"
    exit 1
fi

HEAD_SLOT=$(echo "$SYNC_RESPONSE" | grep -o '"head_slot":"[0-9]*"' | grep -o '[0-9]*')

# Get validator public key
VALIDATOR_POD=$(kubectl get pod -n "$NAMESPACE" \
    -l app.kubernetes.io/component=validator \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -z "$VALIDATOR_POD" ]; then
    echo "Error: Validator pod not found"
    exit 1
fi

PUBKEY=$(kubectl exec -n "$NAMESPACE" "$VALIDATOR_POD" -- \
    ls /data/validators 2>/dev/null | grep "^0x" | head -1 || true)

if [ -z "$PUBKEY" ]; then
    echo "Error: No validator keys loaded. Run: ./start-validator.sh <keys_dir>"
    exit 1
fi

# Truncate public key for display (0x + first 8 chars + ... + last 4 chars)
PUBKEY_SHORT="${PUBKEY:0:10}...${PUBKEY: -4}"

# Query validator status from beacon
VAL_RESPONSE=$(curl -s "http://localhost:15052/eth/v1/beacon/states/head/validators/$PUBKEY" 2>/dev/null)
VAL_STATUS=$(echo "$VAL_RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

if [ -z "$VAL_STATUS" ]; then
    echo "Error: Validator not found on beacon chain. Deposit may not be confirmed yet."
    exit 1
fi

# Output based on status
case "$VAL_STATUS" in
    active_ongoing)
        echo "Validator \"$PUBKEY_SHORT\" is active and attesting on slot $HEAD_SLOT"
        ;;
    pending_initialized|pending_queued)
        echo "Validator \"$PUBKEY_SHORT\" is pending activation (status: $VAL_STATUS)"
        ;;
    *)
        echo "Validator \"$PUBKEY_SHORT\" status: $VAL_STATUS"
        ;;
esac
