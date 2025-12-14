#!/bin/bash
set -e

NS="${ETH_NAMESPACE:-eth-validator}"

echo "=== Validator Health ==="
echo ""

# Pods
echo "Pods:"
kubectl get pods -n $NS -o wide 2>/dev/null || echo "  No pods found"
echo ""

# Beacon sync - use port-forward
BEACON=$(kubectl get pod -n $NS -l app.kubernetes.io/component=consensus -o name 2>/dev/null | head -1)
if [[ -n "$BEACON" ]]; then
    kubectl port-forward -n $NS $BEACON 15052:5052 &>/dev/null &
    PID=$!; sleep 2
    
    echo "Beacon:"
    SYNC=$(curl -s localhost:15052/eth/v1/node/syncing 2>/dev/null)
    if echo "$SYNC" | grep -q '"is_syncing":false'; then
        SLOT=$(echo "$SYNC" | grep -o '"head_slot":"[0-9]*"' | grep -o '[0-9]*')
        echo "  Synced at slot $SLOT"
    else
        DIST=$(echo "$SYNC" | grep -o '"sync_distance":"[0-9]*"' | grep -o '[0-9]*')
        echo "  Syncing... distance=$DIST"
    fi
    
    # Validator status
    echo ""
    echo "Validator:"
    VALPOD=$(kubectl get pod -n $NS -l app.kubernetes.io/component=validator -o name 2>/dev/null | head -1)
    if [[ -n "$VALPOD" ]]; then
        PUBKEY=$(kubectl exec -n $NS ${VALPOD#*/} -- ls /data/validators 2>/dev/null | grep "^0x" | head -1 || true)
        if [[ -n "$PUBKEY" ]]; then
            STATUS=$(curl -s "localhost:15052/eth/v1/beacon/states/head/validators/$PUBKEY" 2>/dev/null)
            VAL_STATUS=$(echo "$STATUS" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
            echo "  $PUBKEY"
            if [[ "$VAL_STATUS" == "active_ongoing" ]]; then
                echo "  Status: ACTIVE and attesting on slot $SLOT"
            else
                echo "  Status: $VAL_STATUS"
            fi
        else
            echo "  No keys loaded. Run ./start-validator.sh <keys_dir>"
        fi
    fi
    
    kill $PID 2>/dev/null || true
fi

# Geth
echo ""
echo "Geth:"
GETH=$(kubectl get pod -n $NS -l app.kubernetes.io/component=execution -o name 2>/dev/null | head -1)
if [[ -n "$GETH" ]]; then
    SYNC=$(kubectl exec -n $NS ${GETH#*/} -- geth attach --exec "eth.syncing" /data/geth.ipc 2>/dev/null || echo "starting")
    if [[ "$SYNC" == "false" ]]; then
        BLOCK=$(kubectl exec -n $NS ${GETH#*/} -- geth attach --exec "eth.blockNumber" /data/geth.ipc 2>/dev/null)
        echo "  Synced at block $BLOCK"
    else
        echo "  Syncing..."
    fi
fi
