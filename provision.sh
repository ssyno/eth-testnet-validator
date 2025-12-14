#!/bin/bash
set -e

NS="${ETH_NAMESPACE:-eth-validator}"

./scripts/kind-setup.sh

kubectl get ns $NS &>/dev/null || kubectl create ns $NS

kubectl get secret eth-jwt -n $NS &>/dev/null || \
    kubectl create secret generic eth-jwt -n $NS \
        --from-literal=jwtsecret=$(openssl rand -hex 32)

helm upgrade --install eth-validator charts/eth-validator -n $NS -f values-dev.yaml

echo "Done. Run ./start-validator.sh <keys_dir> to import keys."
