# External Secrets Integration

Securely manage validator keystores and JWT secrets using KMS/Vault instead of Kubernetes secrets.

## Overview

This integration uses [External Secrets Operator](https://external-secrets.io) to sync secrets from external secret management systems into Kubernetes secrets at runtime.

**Supported Providers:**
- AWS Secrets Manager
- HashiCorp Vault

## Quick Start

### 1. Install External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system --create-namespace
```

### 2. Choose Your Provider

- **[AWS Secrets Manager](aws-kms.yaml)** - For AWS EKS deployments
- **[HashiCorp Vault](hashicorp-vault.yaml)** - Self-hosted or HCP Vault

### 3. Deploy Validator with External Secrets

```bash
# Apply the SecretStore for your provider
kubectl apply -f examples/external-secrets/aws-kms.yaml  # or hashicorp-vault.yaml

# Deploy with external secrets enabled
helm upgrade eth-validator ./charts/eth-validator \
  -n eth-validator \
  --values values-cloud.yaml \
  --set externalSecrets.enabled=true \
  --set externalSecrets.secretStore=aws-secretsmanager \
  --set externalSecrets.validatorPassword.enabled=true \
  --set externalSecrets.validatorPassword.key=eth-validator/validator-password \
  --set externalSecrets.jwtSecret.enabled=true \
  --set externalSecrets.jwtSecret.key=eth-validator/jwt-secret
```

## How It Works

1. **SecretStore** - Defines connection to your KMS/Vault
2. **ExternalSecret** - Syncs specific secrets from KMS/Vault to K8s secrets
3. **Validator pods** - Use the K8s secrets (transparently managed by ESO)

```
┌─────────────────┐
│   AWS/Vault     │  Stores encrypted secrets
│   (KMS/Vault)   │
└────────┬────────┘
         │
         │ (ESO syncs)
         ▼
┌─────────────────┐
│  K8s Secret     │  Created/managed by ESO
│ eth-jwt         │
│ validator-keys  │
└────────┬────────┘
         │
         │ (mounted)
         ▼
┌─────────────────┐
│ Validator Pods  │  Use secrets transparently
└─────────────────┘
```

## Security Benefits

- **No secrets in Git** - Only references to KMS/Vault paths
- **Automatic rotation** - ESO refreshes secrets periodically
- **Audit trail** - KMS/Vault logs all secret access
- **Access control** - IAM/RBAC policies control who can read secrets
- **Encryption at rest** - Managed by cloud provider KMS

## Configuration Options

### values.yaml

```yaml
externalSecrets:
  enabled: true
  secretStore: "aws-secretsmanager"  # Name of your SecretStore
  secretStoreKind: SecretStore  # SecretStore or ClusterSecretStore
  refreshInterval: 1h  # How often to sync from KMS/Vault

  validatorPassword:
    enabled: true
    key: "eth-validator/validator-password"  # Path in KMS/Vault
    property: ""  # Optional: for nested JSON secrets

  jwtSecret:
    enabled: true
    key: "eth-validator/jwt-secret"
    property: ""
```

## Troubleshooting

### Check ExternalSecret status

```bash
kubectl get externalsecret -n eth-validator
kubectl describe externalsecret eth-validator-validator-password -n eth-validator
```

### Verify secret sync

```bash
kubectl get secret eth-jwt -n eth-validator
kubectl get secret eth-validator-keys -n eth-validator
```

### Common issues

**Secret not syncing:**
- Check SecretStore connection: `kubectl describe secretstore -n eth-validator`
- Verify IAM/Vault permissions
- Check ESO logs: `kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets`

**Access denied:**
- AWS: Verify IAM role attached to ServiceAccount
- Vault: Check policy and role configuration
