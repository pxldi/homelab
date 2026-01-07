# Homelab

![Kubernetes](https://img.shields.io/badge/kubernetes-v1.31-blue?logo=kubernetes)
![Talos](https://img.shields.io/badge/talos-v1.8-orange?logo=linux)
![Flux](https://img.shields.io/badge/flux-v2-purple?logo=flux)
![Renovate](https://img.shields.io/badge/renovate-enabled-brightgreen?logo=renovatebot)

GitOps-managed Kubernetes homelab running on Talos Linux with Flux CD.

## 📋 Stack

- **OS**: [Talos Linux](https://www.talos.dev/) - Immutable Kubernetes OS
- **GitOps**: [Flux CD](https://fluxcd.io/) - Continuous delivery
- **Secrets**: [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age) - Encrypted secrets
- **Backup**: [Backblaze B2](https://www.backblaze.com/b2/cloud-storage.html) - Offsite backups

## 📁 Repository Structure

```
.
├── flux/
│   ├── flux-system/         # Flux core components
│   ├── infra/               # Infrastructure components
│   ├── apps/                # Applications
│   ├── secrets/             # SOPS-encrypted secrets
│   └── sources/             # Flux sources (HelmRepositories)
├── .sops.yaml               # SOPS configuration
└── README.md
```

## 🏗️ Infrastructure

| Component | Purpose |
|-----------|---------|
| **authelia** | SSO authentication |
| **cert-manager** | TLS certificates |
| **cilium** | CNI networking |
| **coredns** | Cluster DNS |
| **longhorn** | Distributed storage |
| **metallb** | LoadBalancer IPs |
| **traefik** | Ingress controller |

**Networking:** Pi-hole DNS, Tailscale VPN, Traefik ingress with Authelia SSO  
**Storage:** Longhorn with daily backups to Backblaze B2 (7d/4w/3m retention)  
**External Access:** Services exposed via Traefik ingress, secured with Authelia authentication

## 📦 Applications

| Application | Purpose | Notes |
|-------------|---------|-------|
| **home-assistant** | Home automation | Smart home control |
| **homepage** | Dashboard | Service overview |
| **immich** | Photo management | ML-powered search, mobile sync |
| **jellyfin** | Media server | Movies, TV, music |
| **nextcloud** | File sync & productivity | Files, Calendar (aCalendar+ via DAVx⁵), Contacts (via DAVx⁵), Tasks (tasks.org via DAVx⁵) |
| **pihole** | DNS & ad-blocking | Network-wide ad & telemetry filtering |
| **prometheus-stack** | Monitoring | Prometheus, Grafana, Alertmanager |
| **tandoor** | Recipe management | Meal planning |
| **tailscale** | VPN mesh | Secure remote access, routes DNS through Pi-hole when away from home |

## 🔐 Secrets Management

All secrets encrypted with SOPS + age before commit.

```bash
# Encrypt
sops --encrypt secret.yaml > secret.enc.yaml

# Decrypt  
sops --decrypt secret.enc.yaml

# Edit in-place
sops secret.enc.yaml
```

## 🚀 Quick Start

```bash
# Bootstrap Flux
flux install

# Add SOPS age key
kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=./age.key

# Apply configuration
kubectl apply -k ./flux

# Verify
flux get kustomizations
```

## 🔄 Updates

Renovate Bot handles dependency updates automatically:

- Patch/digest updates: Auto-merged directly to branch (no PRs)
- Minor updates: Auto-merged via PR
- Major updates: PR created for manual review
- Security vulnerabilities: Alerts enabled
