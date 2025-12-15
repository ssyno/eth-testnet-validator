# Architecture

Overview of the Ethereum validator stack components and their interactions.

## System Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Production Architecture                               │
│                                                                                 │
│  ┌──────────────┐     ┌──────────────────────────────────────────────────────┐  │
│  │   Secrets    │     │              Kubernetes Cluster                      │  │
│  │   ─────────  │     │                                                      │  │
│  │ ┌──────────┐ │     │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │ │  Vault   │─┼─────┼─▶│    Geth     │──│  Lighthouse │──│  Lighthouse │   │  │
│  │ │   KMS    │ │     │  │ (execution) │  │  (beacon)   │  │ (validator) │   │  │
│  │ └──────────┘ │     │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘   │  │
│  └──────────────┘     │         │                │                │          │  │
│                       │         ▼                ▼                ▼          │  │
│  ┌──────────────┐     │  ┌─────────────────────────────────────────────────┐ │  │
│  │  Monitoring  │     │  │              Persistent Volumes                 │ │  │
│  │  ──────────  │     │  │   (100Gi geth)  (100Gi beacon)  (10Gi validator)│ │  │
│  │ ┌──────────┐ │     │  └─────────────────────────────────────────────────┘ │  │
│  │ │Prometheus│◀┼─────└──────────────────────────────────────────────────────┘  │
│  │ │ Grafana  │ │                                                               │
│  │ │AlertMgr  │ │                                                               │
│  │ └──────────┘ │                                                               │
│  └──────────────┘                    ┌─────────────────┐                        │
│                                      │  P2P Network    │                        │
│  ┌──────────────┐                    │  ────────────── │                        │
│  │   Backup     │                    │  Port 30303/tcp │◀── Execution P2P       │
│  │  ──────────  │                    │  Port 30303/udp │                        │
│  │  S3/GCS/R2   │                    │  Port 9000/tcp  │◀── Consensus P2P       │
│  │  snapshots   │                    │  Port 9000/udp  │                        │
│  └──────────────┘                    └─────────────────┘                        │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Components

### Execution Layer (Geth)

The execution client processes transactions and maintains the Ethereum state.

| Port | Protocol | Purpose |
|------|----------|---------|
| 8545 | HTTP | JSON-RPC API |
| 8546 | WebSocket | Subscriptions |
| 8551 | HTTP | Engine API (JWT auth) |
| 30303 | TCP/UDP | P2P networking |
| 6060 | HTTP | Metrics |

### Consensus Layer (Lighthouse Beacon)

The beacon node tracks the beacon chain and coordinates with the execution layer.

| Port | Protocol | Purpose |
|------|----------|---------|
| 5052 | HTTP | Beacon API |
| 9000 | TCP/UDP | P2P networking |
| 9001 | UDP | QUIC transport |
| 5054 | HTTP | Metrics |

### Validator Client (Lighthouse Validator)

The validator client manages validator keys and performs duties (attestations, proposals).

| Port | Protocol | Purpose |
|------|----------|---------|
| 5064 | HTTP | Metrics |

## Data Flow

1. **Block Production**
   ```
   P2P Network → Beacon Node → Execution Client → Block Built
                     ↓
              Validator Client → Signs Block
                     ↓
              Beacon Node → Broadcasts to Network
   ```

2. **Attestations**
   ```
   Beacon Node → Requests Attestation Data
        ↓
   Validator Client → Signs Attestation
        ↓
   Beacon Node → Broadcasts to Network
   ```

3. **Sync**
   ```
   P2P Network → Beacon Node (checkpoint sync)
        ↓
   Beacon Node → Engine API → Geth (execution sync)
   ```

## Storage Requirements

| Component | Minimum | Recommended | Growth Rate |
|-----------|---------|-------------|-------------|
| Geth | 100 GB | 500 GB | ~10 GB/month |
| Beacon | 50 GB | 200 GB | ~5 GB/month |
| Validator | 1 GB | 10 GB | Minimal |

## Network Requirements

- **Bandwidth**: 10+ Mbps sustained, 100+ Mbps burst
- **Latency**: <100ms to peers for optimal attestation inclusion
- **Ports**: 30303, 9000 must be reachable from internet (TCP+UDP)

## High Availability

### Multi-Beacon Setup

```yaml
lighthouse:
  beacon:
    replicaCount: 2  # Behind load balancer
    
  validator:
    extraArgs:
      - "--beacon-nodes=http://beacon-0:5052,http://beacon-1:5052"
```

**WARNING**: Never run multiple validator instances with the same keys. This causes slashing.

### Disaster Recovery

```bash
# Backup slashing protection database
kubectl exec -n eth-validator eth-validator-validator-0 -- \
    lighthouse account validator slashing-protection export \
    --datadir /data \
    /tmp/slashing-protection.json

kubectl cp eth-validator/eth-validator-validator-0:/tmp/slashing-protection.json ./backup/

# Before restoring, ALWAYS import slashing protection first
lighthouse account validator slashing-protection import \
    --datadir /data \
    /backup/slashing-protection.json
```
