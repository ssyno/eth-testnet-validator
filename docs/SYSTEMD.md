# systemd Deployment

Guide for running the Ethereum validator stack as systemd services on bare metal Linux.

## Overview

This deployment method is ideal for:
- Dedicated validator hardware
- Minimal overhead (no container runtime)
- Direct hardware access
- Single-node deployments

## Prerequisites

- Ubuntu 22.04+ or Debian 12+
- 16+ GB RAM
- 1+ TB SSD (NVMe recommended)
- Static IP with ports 30303 and 9000 forwarded

## Installation

### 1. Install Clients

```bash
# Create ethereum user
sudo useradd --no-create-home --shell /bin/false ethereum

# Download Geth
GETH_VERSION="1.14.7"
wget https://gethstore.blob.core.windows.net/builds/geth-linux-amd64-${GETH_VERSION}.tar.gz
tar xzf geth-linux-amd64-*.tar.gz
sudo cp geth-linux-amd64-*/geth /usr/local/bin/
rm -rf geth-linux-amd64-*

# Download Lighthouse
LH_VERSION="v5.2.0"
wget https://github.com/sigp/lighthouse/releases/download/${LH_VERSION}/lighthouse-${LH_VERSION}-x86_64-unknown-linux-gnu.tar.gz
tar xzf lighthouse-*.tar.gz
sudo cp lighthouse /usr/local/bin/
rm lighthouse-*.tar.gz

# Verify installations
geth version
lighthouse --version
```

### 2. Create Directories

```bash
# Data directories
sudo mkdir -p /var/lib/ethereum/{geth,lighthouse-beacon,lighthouse-validator}
sudo chown -R ethereum:ethereum /var/lib/ethereum

# Config directory
sudo mkdir -p /etc/ethereum
sudo chown ethereum:ethereum /etc/ethereum

# Generate JWT secret
openssl rand -hex 32 | sudo tee /etc/ethereum/jwtsecret
sudo chmod 600 /etc/ethereum/jwtsecret
sudo chown ethereum:ethereum /etc/ethereum/jwtsecret
```

### 3. Install Services

Copy the service files from this repository:

```bash
sudo cp systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
```

### 4. Import Validator Keys

```bash
# Copy keys to secure location
sudo mkdir -p /var/lib/ethereum/validator-keys
sudo cp validator_keys/* /var/lib/ethereum/validator-keys/
sudo chown -R ethereum:ethereum /var/lib/ethereum/validator-keys
sudo chmod 600 /var/lib/ethereum/validator-keys/*

# Import keys
sudo -u ethereum lighthouse account validator import \
    --network sepolia \
    --datadir /var/lib/ethereum/lighthouse-validator \
    --directory /var/lib/ethereum/validator-keys \
    --password-file /var/lib/ethereum/validator-keys/password.txt \
    --reuse-password
```

### 5. Configure Fee Recipient

Edit the validator service to set your fee recipient address:

```bash
sudo systemctl edit eth-validator
```

Add:
```ini
[Service]
Environment="FEE_RECIPIENT=0xYourAddressHere"
```

### 6. Start Services

```bash
# Enable and start all services
sudo systemctl enable --now eth-geth eth-beacon eth-validator

# Check status
sudo systemctl status eth-geth eth-beacon eth-validator
```

## Service Files

### eth-geth.service

```ini
[Unit]
Description=Geth Execution Client (Sepolia)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ethereum
Group=ethereum
Restart=always
RestartSec=5
TimeoutStopSec=300

Environment=DATADIR=/var/lib/ethereum/geth
Environment=JWT_SECRET=/etc/ethereum/jwtsecret

ExecStart=/usr/local/bin/geth \
    --sepolia \
    --datadir=${DATADIR} \
    --http \
    --http.addr=127.0.0.1 \
    --http.api=eth,net,web3,engine \
    --authrpc.addr=127.0.0.1 \
    --authrpc.jwtsecret=${JWT_SECRET} \
    --metrics \
    --metrics.addr=127.0.0.1 \
    --metrics.port=6060

NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/ethereum/geth

[Install]
WantedBy=multi-user.target
```

### eth-beacon.service

```ini
[Unit]
Description=Lighthouse Beacon Node (Sepolia)
After=network-online.target eth-geth.service
Wants=network-online.target
Requires=eth-geth.service

[Service]
Type=simple
User=ethereum
Group=ethereum
Restart=always
RestartSec=5
TimeoutStopSec=300

Environment=DATADIR=/var/lib/ethereum/lighthouse-beacon
Environment=JWT_SECRET=/etc/ethereum/jwtsecret

ExecStart=/usr/local/bin/lighthouse beacon_node \
    --network=sepolia \
    --datadir=${DATADIR} \
    --execution-endpoint=http://127.0.0.1:8551 \
    --execution-jwt=${JWT_SECRET} \
    --checkpoint-sync-url=https://sepolia.beaconstate.info/ \
    --http \
    --http-address=127.0.0.1 \
    --http-port=5052 \
    --metrics \
    --metrics-address=127.0.0.1 \
    --metrics-port=5054

NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/ethereum/lighthouse-beacon

[Install]
WantedBy=multi-user.target
```

### eth-validator.service

```ini
[Unit]
Description=Lighthouse Validator Client (Sepolia)
After=network-online.target eth-beacon.service
Wants=network-online.target
Requires=eth-beacon.service

[Service]
Type=simple
User=ethereum
Group=ethereum
Restart=always
RestartSec=5

Environment=DATADIR=/var/lib/ethereum/lighthouse-validator
Environment=FEE_RECIPIENT=0x0000000000000000000000000000000000000000
Environment=GRAFFITI=eth-validator

ExecStart=/usr/local/bin/lighthouse validator_client \
    --network=sepolia \
    --datadir=${DATADIR} \
    --beacon-nodes=http://127.0.0.1:5052 \
    --suggested-fee-recipient=${FEE_RECIPIENT} \
    --graffiti=${GRAFFITI} \
    --metrics \
    --metrics-address=127.0.0.1 \
    --metrics-port=5064

NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/ethereum/lighthouse-validator

[Install]
WantedBy=multi-user.target
```

## Management

### View Logs

```bash
# Follow all logs
journalctl -u eth-geth -u eth-beacon -u eth-validator -f

# View specific service
journalctl -u eth-beacon -f

# View last 100 lines
journalctl -u eth-validator -n 100
```

### Restart Services

```bash
# Restart single service
sudo systemctl restart eth-beacon

# Restart all
sudo systemctl restart eth-geth eth-beacon eth-validator
```

### Update Clients

```bash
# Stop services
sudo systemctl stop eth-validator eth-beacon eth-geth

# Download and install new versions
# ... (follow installation steps)

# Start services
sudo systemctl start eth-geth eth-beacon eth-validator
```

## Monitoring

### Prometheus Node Exporter

```bash
# Install node exporter
sudo apt install prometheus-node-exporter

# Add to prometheus scrape config
# - job_name: 'ethereum'
#   static_configs:
#     - targets: ['localhost:6060', 'localhost:5054', 'localhost:5064']
```

### Health Check Script

Create `/usr/local/bin/eth-health-check`:

```bash
#!/bin/bash

echo "=== Ethereum Validator Health ==="

# Geth
GETH_SYNC=$(curl -s -X POST http://127.0.0.1:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' | jq -r '.result')

echo "Geth: $([ "$GETH_SYNC" = "false" ] && echo "Synced" || echo "Syncing")"

# Beacon
BEACON_SYNC=$(curl -s http://127.0.0.1:5052/eth/v1/node/syncing | jq -r '.data.is_syncing')
BEACON_SLOT=$(curl -s http://127.0.0.1:5052/eth/v1/node/syncing | jq -r '.data.head_slot')

echo "Beacon: $([ "$BEACON_SYNC" = "false" ] && echo "Synced at slot $BEACON_SLOT" || echo "Syncing")"

# Validator
PUBKEY=$(ls /var/lib/ethereum/lighthouse-validator/validators/ 2>/dev/null | grep "^0x" | head -1)
if [ -n "$PUBKEY" ]; then
    STATUS=$(curl -s "http://127.0.0.1:5052/eth/v1/beacon/states/head/validators/$PUBKEY" | jq -r '.data.status')
    echo "Validator: $PUBKEY"
    echo "Status: $STATUS"
else
    echo "Validator: No keys loaded"
fi
```

Make executable:
```bash
sudo chmod +x /usr/local/bin/eth-health-check
```

## Troubleshooting

### Service Won't Start

```bash
# Check for errors
journalctl -u eth-geth -n 50 --no-pager

# Verify permissions
ls -la /var/lib/ethereum/
ls -la /etc/ethereum/
```

### Port Already in Use

```bash
# Find process using port
sudo lsof -i :8545
sudo lsof -i :5052
```

### Disk Full

```bash
# Check disk usage
df -h /var/lib/ethereum/

# Prune Geth (if needed)
sudo systemctl stop eth-geth
sudo -u ethereum geth --datadir /var/lib/ethereum/geth snapshot prune-state
sudo systemctl start eth-geth
```
