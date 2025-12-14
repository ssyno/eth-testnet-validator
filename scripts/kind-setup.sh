#!/bin/bash
set -e

NAME="${KIND_CLUSTER_NAME:-eth-validator}"

if kind get clusters 2>/dev/null | grep -q "^$NAME$"; then
    echo "Cluster $NAME exists"
    exit 0
fi

cat <<EOF | kind create cluster --name $NAME --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30303
        hostPort: 30303
      - containerPort: 9000
        hostPort: 9000
EOF
