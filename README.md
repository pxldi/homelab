# Homelab

GitOps-managed Kubernetes homelab running on Talos Linux with Flux CD.

## Stack

- **OS**: [Talos Linux](https://www.talos.dev/) - Immutable Kubernetes OS
- **GitOps**: [Flux CD](https://fluxcd.io/) - Continuous delivery of my changes
- **Secrets**: [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age) for encrypting my secrets

## Repository Structure

```text
.
├── flux/
│   ├── flux-system/         # Flux core components
│   ├── infra/               # Infrastructure
│   ├── apps/                # Applications
│   ├── secrets/             # SOPS-encrypted secrets
│   ├── sources/             # Flux sources
│   └── kustomization.yaml   # Root kustomization
├── .sops.yaml               # SOPS configuration
└── README.md
```

## Infrastructure 

TBD

## Applications

TBD

## Secrets Management

All secrets are encrypted using SOPS with age encryption:

```bash
# Encrypt using public key
sops --e secret.yaml > secret.enc.yaml

# Decrypt using private key
sops --d secret.enc.yaml > secret.yaml
```