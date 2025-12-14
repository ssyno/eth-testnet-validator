#!/bin/bash
set -e

NS="${ETH_NAMESPACE:-eth-validator}"
KEYS_DIR="$1"

[[ -z "$KEYS_DIR" ]] && echo "Usage: $0 <keys_dir>" && exit 1
[[ ! -d "$KEYS_DIR" ]] && echo "Not found: $KEYS_DIR" && exit 1
[[ ! -f "$KEYS_DIR/password.txt" ]] && echo "Missing: $KEYS_DIR/password.txt" && exit 1

TMP=$(mktemp -d)
trap "rm -rf $TMP" EXIT

tar -czf $TMP/keys.tar.gz -C "$KEYS_DIR" .
cp "$KEYS_DIR/password.txt" $TMP/password.txt

kubectl delete secret eth-validator-keys -n $NS 2>/dev/null || true
kubectl create secret generic eth-validator-keys -n $NS \
    --from-file=validator_keys.tar.gz=$TMP/keys.tar.gz \
    --from-file=validator_password.txt=$TMP/password.txt

kubectl rollout restart statefulset -l app.kubernetes.io/component=validator -n $NS

echo "Done. Run ./check-health.sh"
