#!/bin/bash
#
# check-health.sh - Verify validator health and sync status
#
# Outputs human-readable status including:
#   - Pod status
#   - Beacon sync status
#   - Validator attestation status
#   - Execution client sync status
#
set -e

NAMESPACE="${ETH_NAMESPACE:-eth-validator}"

echo "=== Ethereum Validator Health Check ==="
echo ""

# Check pods
echo "Pods:"
kubectl get pods -n "$NAMESPACE" -o wide 2>/dev/null || echo "  No pods found"
echo ""

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

# Check beacon sync status
echo "Beacon Node:"
SYNC_RESPONSE=$(curl -s http://localhost:15052/eth/v1/node/syncing 2>/dev/null)

if [ -z "$SYNC_RESPONSE" ]; then
    echo "  Error: Could not connect to beacon API"
    exit 1
fi

IS_SYNCING=$(echo "$SYNC_RESPONSE" | grep -o '"is_syncing":[^,}]*' | cut -d: -f2)
HEAD_SLOT=$(echo "$SYNC_RESPONSE" | grep -o '"head_slot":"[0-9]*"' | grep -o '[0-9]*')
SYNC_DISTANCE=$(echo "$SYNC_RESPONSE" | grep -o '"sync_distance":"[0-9]*"' | grep -o '[0-9]*')

if [ "$IS_SYNCING" = "false" ]; then
    echo "  Status: Synced"
    echo "  Head slot: $HEAD_SLOT"
else
    echo "  Status: Syncing"
    echo "  Head slot: $HEAD_SLOT"
    echo "  Sync distance: $SYNC_DISTANCE slots"
fi

# Check peer count
PEERS=$(curl -s http://localhost:15052/eth/v1/node/peer_count 2>/dev/null)
CONNECTED=$(echo "$PEERS" | grep -o '"connected":"[0-9]*"' | grep -o '[0-9]*')
echo "  Peers: ${CONNECTED:-0}"
echo ""

# Check validator status
echo "Validator:"
VALIDATOR_POD=$(kubectl get pod -n "$NAMESPACE" \
    -l app.kubernetes.io/component=validator \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -z "$VALIDATOR_POD" ]; then
    echo "  Pod not found"
else
    # Get validator public key
    PUBKEY=$(kubectl exec -n "$NAMESPACE" "$VALIDATOR_POD" -- \
        ls /data/validators 2>/dev/null | grep "^0x" | head -1 || true)
    
    if [ -z "$PUBKEY" ]; then
        echo "  No validator keys loaded"
        echo "  Run: ./start-validator.sh <keys_dir>"
    else
        echo "  Public key: $PUBKEY"
        
        # Query validator status from beacon
        VAL_RESPONSE=$(curl -s "http://localhost:15052/eth/v1/beacon/states/head/validators/$PUBKEY" 2>/dev/null)
        VAL_STATUS=$(echo "$VAL_RESPONSE" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        VAL_BALANCE=$(echo "$VAL_RESPONSE" | grep -o '"balance":"[0-9]*"' | grep -o '[0-9]*')
        
        if [ -n "$VAL_STATUS" ]; then
            # Convert balance from Gwei to ETH
            if [ -n "$VAL_BALANCE" ]; then
                ETH_BALANCE=$(echo "scale=4; $VAL_BALANCE / 1000000000" | bc 2>/dev/null || echo "$VAL_BALANCE Gwei")
            fi
            
            case "$VAL_STATUS" in
                active_ongoing)
                    echo ""
                    echo "  ✓ Validator $PUBKEY is ACTIVE and attesting on slot $HEAD_SLOT"
                    echo "  Balance: $ETH_BALANCE ETH"
                    ;;
                pending_initialized|pending_queued)
                    echo "  Status: $VAL_STATUS (waiting for activation)"
                    echo "  Note: Deposit confirmed, waiting for validator queue"
                    ;;
                *)
                    echo "  Status: $VAL_STATUS"
                    [ -n "$ETH_BALANCE" ] && echo "  Balance: $ETH_BALANCE ETH"
                    ;;
            esac
        else
            echo "  Status: Not found on beacon chain"
            echo "  Note: Validator may not be deposited yet"
            echo "  Deposit at: https://sepolia.launchpad.ethereum.org/"
        fi
    fi
fi
echo ""

# Check Geth status
echo "Execution Client (Geth):"
GETH_POD=$(kubectl get pod -n "$NAMESPACE" \
    -l app.kubernetes.io/component=execution \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

if [ -z "$GETH_POD" ]; then
    echo "  Pod not found"
else
    GETH_SYNC=$(kubectl exec -n "$NAMESPACE" "$GETH_POD" -- \
        geth attach --exec "eth.syncing" /data/geth.ipc 2>/dev/null || echo "error")
    
    if [ "$GETH_SYNC" = "false" ]; then
        BLOCK=$(kubectl exec -n "$NAMESPACE" "$GETH_POD" -- \
            geth attach --exec "eth.blockNumber" /data/geth.ipc 2>/dev/null || echo "unknown")
        echo "  Status: Synced"
        echo "  Block: $BLOCK"
    elif [ "$GETH_SYNC" = "error" ]; then
        echo "  Status: Starting..."
    else
        echo "  Status: Syncing..."
    fi
    
    # Peer count
    GETH_PEERS=$(kubectl exec -n "$NAMESPACE" "$GETH_POD" -- \
        geth attach --exec "admin.peers.length" /data/geth.ipc 2>/dev/null || echo "0")
    echo "  Peers: $GETH_PEERS"
fi
