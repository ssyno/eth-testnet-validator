# Ethereum Testnet Validator

Ethereum Sepolia testnet validator on Kubernetes — deployable with **3 commands**.

## Quick Start

```bash
# 1. Provision infrastructure
./provision.sh

# 2. Start validator with your keys
./start-validator.sh ./validator_keys

# 3. Check health
./check-health.sh
```

## Requirements

- kubectl, helm, kind, docker, openssl

## Generate Validator Keys

Use the [ethstaker-deposit-cli](https://github.com/ethstaker/ethstaker-deposit-cli) (actively maintained fork):

```bash
# Download (Mac)
curl -LO https://github.com/ethstaker/ethstaker-deposit-cli/releases/download/v1.2.2/ethstaker_deposit-cli-b13dcb9-darwin-amd64.tar.gz
tar xzf ethstaker_deposit-cli-*.tar.gz
cd ethstaker_deposit-cli-*/

# Generate keys for Sepolia testnet
./deposit new-mnemonic --num_validators 1 --chain sepolia

# Follow prompts:
#   - Choose language
#   - Create a password (save this!)
#   - Write down mnemonic (24 words) - KEEP THIS SAFE
#   - Confirm mnemonic
```

This creates a `validator_keys/` folder containing:
- `keystore-*.json` - encrypted validator key
- `deposit_data-*.json` - for depositing 32 ETH

Create a password file:
```bash
echo "your-password-here" > validator_keys/password.txt
```

**To activate your validator**, deposit 32 Sepolia ETH at:
https://sepolia.launchpad.ethereum.org/

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Kubernetes                                │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │     Geth     │───▶│  Lighthouse  │───▶│  Lighthouse  │       │
│  │  (execution) │JWT │   (beacon)   │HTTP│  (validator) │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│         │                   │                   │                │
│         ▼                   ▼                   ▼                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   Persistent Volumes                         ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                  │
│  P2P Ports: 30303 (Geth), 9000 (Lighthouse)                     │
└─────────────────────────────────────────────────────────────────┘
```

## Deployment Options

### Local (KIND)

Default mode - creates a local Kubernetes cluster:

```bash
./provision.sh
```

Requires port forwarding on your router:
- **30303 TCP/UDP** → your machine (Geth P2P)
- **9000 TCP/UDP** → your machine (Lighthouse P2P)

### Cloud

For cloud Kubernetes with LoadBalancer support:

```bash
# Select you cluster's Kubeconfig & Deploy
./provision.sh --cloud
```

The LoadBalancer automatically discovers its external IP for peer connectivity.

## Commands Reference

| Command | Description |
|---------|-------------|
| `./provision.sh` | Create KIND cluster, deploy Geth + Lighthouse |
| `./provision.sh --cloud` | Deploy to existing cloud Kubernetes cluster |
| `./start-validator.sh <keys>` | Import validator keys |
| `./check-health.sh` | Show sync status and validator state |

## Alternative Deployments

### Docker Compose

For simpler single-machine deployments:

```bash
mkdir -p secrets && openssl rand -hex 32 > secrets/jwtsecret
docker compose up -d
```

### systemd (Bare Metal)

For production Linux servers:

```bash
sudo cp systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now eth-geth eth-beacon eth-validator
```

## Cleanup

```bash
# KIND (local)
helm uninstall eth-validator -n eth-validator
kind delete cluster --name eth-validator

# Docker Compose
docker compose down -v

# Cloud
helm uninstall eth-validator -n eth-validator
```

