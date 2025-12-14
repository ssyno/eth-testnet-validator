#!/bin/bash
set -e
kind delete cluster --name "${KIND_CLUSTER_NAME:-eth-validator}" 2>/dev/null || true
