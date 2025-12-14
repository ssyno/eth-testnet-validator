# eth-testnet-validator

Ethereum Sepolia testnet validator on Kubernetes — deployable with **3 commands**.

## Quick Start

```bash
# 1. Provision infrastructure (Kind cluster, secrets, deploy)
./provision.sh

# 2. Start validator with your keys
./start-validator.sh /path/to/validator_keys

# 3. Check health
./check-health.sh
```

## Requirements

- kubectl, helm, kind, docker, openssl

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes (Kind)                         │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐   │
│  │    Geth     │──│  Lighthouse  │──│    Lighthouse     │   │
│  │ (execution) │  │   (beacon)   │  │   (validator)     │   │
│  └─────────────┘  └──────────────┘  └───────────────────┘   │
│         │                │                    │              │
│         └────────────────┼────────────────────┘              │
│              eth-jwt     │    eth-validator-keys             │
└─────────────────────────────────────────────────────────────┘
```

## The 3 Commands

### 1. `./provision.sh`

Creates Kind cluster, JWT secret, and deploys the Helm chart.

```bash
./provision.sh
```

Idempotent — safe to run multiple times.

### 2. `./start-validator.sh <keys_dir>`

Imports validator keys and starts the validator.

```bash
./start-validator.sh ./my-validator-keys
```

Keys directory must contain:
- `keystore-*.json` files (from staking-deposit-cli)
- `password.txt` (keystore password)

### 3. `./check-health.sh`

Outputs human-readable health status:

```
=== Ethereum Validator Health Check ===

Pods:
  ✓ eth-validator-geth-0 (Running)
  ✓ eth-validator-beacon-0 (Running)
  ✓ eth-validator-validator-0 (Running)

Beacon Sync:
  ✓ Synced at slot 9167456

Validator:
  ✓ Validator "0xabc123...def456" is active and attesting on slot 9167456

Execution Layer (Geth):
  ✓ Synced at block 7654321
```

## Configuration

Edit `values-dev.yaml` for local settings:

```yaml
lighthouse:
  beacon:
    enrAddress: "YOUR_PUBLIC_IP"  # Required for P2P
```

## P2P Networking

For the beacon to sync, you need either:
1. Port forward 9000 TCP+UDP on your router to your machine
2. Or deploy to a cloud environment with public IP

## Secrets

Secrets are auto-created by `provision.sh`, or create manually:

```bash
# JWT secret
kubectl create secret generic eth-jwt -n eth-validator \
  --from-literal=jwtsecret=$(openssl rand -hex 32)

# Validator keys
kubectl create secret generic eth-validator-keys -n eth-validator \
  --from-file=validator_keys.tar.gz=./keys.tar.gz \
  --from-file=validator_password.txt=./password.txt
```

## Cleanup

```bash
helm uninstall eth-validator -n eth-validator
kind delete cluster --name eth-validator
```

## Security

- No plaintext keys in code
- Persistent storage survives restarts
- Secrets stored in Kubernetes
- Pods run as non-root (UID 1000)
