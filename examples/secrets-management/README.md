# Secrets Management

Options for managing validator keys and JWT secrets securely.

| Method | Best For |
|--------|----------|
| [SOPS](sops.yaml) | GitOps, encrypted secrets in repo |
| [AWS Secrets Manager](aws-kms.yaml) | AWS EKS |
| [HashiCorp Vault](hashicorp-vault.yaml) | Enterprise |

## SOPS

```bash
brew install sops age
age-keygen -o age-key.txt

# Encrypt
sops -e secrets.yaml > secrets.enc.yaml

# Decrypt
sops -d secrets.enc.yaml
```

Works with Flux, ArgoCD, and helm-secrets.

## External Secrets Operator

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets-system --create-namespace
```

Then apply your provider config:

```bash
kubectl apply -f examples/external-secrets/aws-kms.yaml
# or
kubectl apply -f examples/external-secrets/hashicorp-vault.yaml
```
