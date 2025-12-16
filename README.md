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

- **Tools**: `kubectl`, `helm`, `kind` (for local), `docker`, `openssl`
- **Validator Keys**: Generated with [ethstaker-deposit-cli](https://github.com/ethstaker/ethstaker-deposit-cli)

## Deployment Modes

### Local (KIND)

Default mode - creates a local Kubernetes cluster for development:

```bash
./provision.sh
```

**Note**: Requires port forwarding on your router for P2P connectivity:
- **30303 TCP/UDP** → your machine (Geth P2P)
- **9000 TCP/UDP** → your machine (Lighthouse P2P)

### Cloud

For production Kubernetes clusters (GKE, EKS, DigitalOcean, etc.):

```bash
./provision.sh --cloud
```

Automatically discovers external IPs via LoadBalancer services.

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
│                        Kubernetes                               │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │     Geth     │───▶│  Lighthouse  │───▶│  Lighthouse  │       │
│  │  (execution) │JWT │   (beacon)   │HTTP│  (validator) │       │
│  └──────────────┘    └──────────────┘    └──────────────┘       │
│         │                   │                   │               │
│         ▼                   ▼                   ▼               │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   Persistent Volumes                        ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                 │
│  P2P Ports: 30303 (Geth), 9000 (Lighthouse)                     │
└─────────────────────────────────────────────────────────────────┘
```

**Components**:
- **Geth**: Execution layer client (syncs Ethereum blockchain)
- **Lighthouse Beacon**: Consensus layer client (manages beacon chain)
- **Lighthouse Validator**: Validator client (performs attestations)

## Configuration

Deployment configs in `values.yaml`:

Override defaults:
```bash
helm upgrade eth-validator ./charts/eth-validator \
  -n eth-validator \
  --values values.yaml \
  --set lighthouse.validator.graffiti="my-validator"
```

## Monitoring

Metrics exposed on:
- Geth: `:6060/debug/metrics/prometheus`
- Lighthouse Beacon: `:5054/metrics`
- Lighthouse Validator: `:5064/metrics`

Enable Prometheus ServiceMonitor:
```yaml
serviceMonitor:
  enabled: true
```

## Security Features

- JWT authentication between execution/consensus layers
- Encrypted validator keystores (never plaintext keys)
- Pod Security Context (non-root, drop capabilities)
- Network Policies (optional, disabled by default)
- Secret management via Kubernetes secrets

## Cleanup

```bash
# Remove deployment
helm uninstall eth-validator -n eth-validator

# Remove local KIND cluster
kind delete cluster --name eth-validator
```