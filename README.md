# eth-testnet-validator

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
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes (Kind)                         │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐   │
│  │    Geth     │──│  Lighthouse  │──│    Lighthouse     │   │
│  │ (execution) │  │   (beacon)   │  │   (validator)     │   │
│  └─────────────┘  └──────────────┘  └───────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## The 3 Commands

### 1. `./provision.sh`
Creates Kind cluster, JWT secret, and deploys Helm chart. Idempotent.

### 2. `./start-validator.sh <keys_dir>`
Imports validator keys and restarts validator pod.

### 3. `./check-health.sh`
Shows sync status and validator state:
```
=== Validator Health ===

Pods:
NAME                                 READY   STATUS
eth-validator-geth-0                 1/1     Running
eth-validator-beacon-0               1/1     Running
eth-validator-validator-0            1/1     Running

Beacon:
  Synced at slot 9167456

Validator:
  0xabc123...def456
  Status: ACTIVE and attesting on slot 9167456
```

## Configuration

Edit `values-dev.yaml`:
```yaml
lighthouse:
  beacon:
    enrAddress: "YOUR_PUBLIC_IP"  # For P2P connectivity
```

## P2P Networking

For beacon to find peers:
1. Set `enrAddress` to your public IP
2. Port forward 9000 TCP+UDP on your router

Without this, sync distance will keep increasing.

## Cleanup

```bash
helm uninstall eth-validator -n eth-validator
kind delete cluster --name eth-validator
```
