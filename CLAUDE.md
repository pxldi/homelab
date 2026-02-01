# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **Kubernetes-based homelab** running on **Talos Linux** (v1.8), managed by **Flux CD** (v2) using GitOps workflows. The cluster runs Kubernetes v1.31 with Longhorn for storage and Traefik as the ingress controller.

### Key Technologies
- **OS**: Talos Linux (immutable Kubernetes OS)
- **GitOps**: Flux CD for continuous delivery
- **Secrets Management**: SOPS + age encryption (all secrets in `flux/secrets/`)
- **Storage**: Longhorn with multiple storage classes (longhorn, longhorn-dual-disk, longhorn-single-replica)
- **Ingress**: Traefik with automatic TLS via cert-manager
- **Dependency Management**: Renovate bot for automated updates

## Directory Structure

```
flux/
├── apps/           # Application deployments (HelmReleases)
│   ├── media-stack/
│   ├── obsidian-sync/
│   ├── freshrss/
│   └── ...
├── flux-system/    # Flux controllers (do not modify manually)
├── sources/        # HelmRepository definitions (external chart sources)
├── infra/          # Infrastructure components (Traefik, Longhorn, cert-manager, etc.)
├── gameservers/    # Game server deployments
└── secrets/        # SOPS-encrypted secrets
talos/              # Talos machine configurations
bootstrap/          # Cluster bootstrap scripts
```

## Common Commands

### Using Task (task runner)
The repository uses `task` (Taskfile.yaml) as the primary command interface:

```bash
task init              # Initialize repository (first-time setup)
task check-tools       # Verify required tools are installed
task validate          # Validate all Kubernetes manifests (dry-run)
task status            # Show cluster status (context, flux, top)
task secrets           # List all encrypted secret files
task clean             # Clean temporary files
```

### Required Tools
The following tools must be installed:
- `kubectl` - Kubernetes CLI
- `flux` - Flux CD CLI
- `talosctl` - Talos Linux CLI
- `sops` - Secret encryption
- `age` - Encryption backend
- `task` - Task runner

### Direct kubectl/flux commands
```bash
# Get cluster status
kubectl get nodes
flux get all -A

# Check reconciliation status
flux get kustomizations -A
flux get helmreleases -A

# View logs
kubectl logs -n <namespace> <pod>
kubectl logs -n flux-system deployment/flux-operator
```

## Architecture Patterns

### Flux GitOps Structure

The repository follows a hierarchical Flux structure:

1. **Root Kustomization** (`flux/kustomization.yaml`) - Defines the overall structure
2. **Flux Kustomizations** in each subdirectory (`kustomization-flux.yaml`) - Tell Flux how to sync that directory
3. **Local Kustomizations** (`kustomization.yaml`) - Standard Kustomize resources

Example from `flux/apps/kustomization-flux.yaml`:
- Syncs `./flux/apps` every 5 minutes
- Uses SOPS for decryption
- Depends on `infra` kustomization

### HelmRelease Pattern

Applications are deployed using HelmReleases. Example pattern from `flux/apps/media-stack/jellyfin.yaml`:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: jellyfin
  namespace: media-stack
spec:
  interval: 1h
  chart:
    spec:
      chart: jellyfin
      version: "22.2.25"
      sourceRef:
        kind: HelmRepository
        name: truecharts
        namespace: flux-system
  values:
    # Helm values go here
```

### Adding a New Application

1. Create namespace in `flux/apps/namespaces/` or appropriate location
2. Create app directory (e.g., `flux/apps/myapp/`)
3. Create `HelmRelease` YAML file referencing a HelmRepository from `flux/sources/`
4. Create `kustomization.yaml` listing all resources
5. Add to parent `kustomization-flux.yaml` or create appropriate Flux Kustomization

### Storage Classes

- `longhorn` - Default (3 replicas)
- `longhorn-dual-disk` - 2 replicas
- `longhorn-single-replica` - 1 replica (for cache/temporary data)

### Ingress Pattern

All applications use Traefik ingress with this pattern:

```yaml
ingress:
  main:
    enabled: true
    ingressClassName: traefik
    annotations:
      traefik.ingress.kubernetes.io/router.entrypoints: websecure
      traefik.ingress.kubernetes.io/router.tls.certresolver: myresolver
    hosts:
      - host: app.pxldi.de
        paths:
          - path: /
            pathType: Prefix
```

## Secret Management

Secrets are encrypted using SOPS with age. The encryption key is stored in `.sops.yaml`.

To edit a secret:
```bash
sops flux/secrets/<secret-file>.yaml
```

To encrypt a new secret:
```bash
sops --encrypt <file>.yaml > <file>.sops.yaml
```

## CI/CD

### GitHub Actions

- **Flux Diff** (`.github/workflows/flux-diff.yaml`): Runs on PRs against `main` branch
  - Uses `flux-local` to show diffs of changes
  - Comments on PRs with resource changes
  - Only runs when files in `kubernetes/` directory change

### Renovate Bot

Automated dependency updates via Renovate:
- Helm chart versions
- Container images
- Kubernetes API versions
- Custom dependencies via `# renovate:` comments

Configuration in `renovaterc.json5`:
- Patch updates auto-merged
- Grouped updates for Flux and Talos
- Scheduled weekend updates for container images

## Important Notes

- **Never manually edit resources in `flux/flux-system/`** - These are managed by Flux
- **Always validate changes** with `task validate` before committing
- **SOPS encrypts** `data` and `stringData` fields automatically (see `.sops.yaml`)
- **Chart sources** are defined in `flux/sources/` as HelmRepository resources
- **TrueCharts** is the primary Helm repository (OCI-based: `oci://oci.trueforge.org/truecharts`)
- **Dependencies**: Apps depend on `infra`, so infrastructure is deployed first
- **Backup**: PVCs labeled appropriately are backed up to Backblaze B2 via Longhorn recurring jobs

## Application Categories

### Media Stack
- Jellyfin (media server)
- Radarr (movies)
- Sonarr (TV series)
- SABnzbd (downloader)

### Productivity
- Nextcloud (file sync)
- Obsidian Sync (notes, via CouchDB)
- FreshRSS (feed reader)
- Tandoor (recipes)

### Infrastructure
- Home Assistant (home automation)
- Pi-hole (DNS/ad blocking)
- Traefik (ingress)
- Cert-manager (TLS certificates)
- Longhorn (storage)
- Glances (monitoring)

### Gaming
- Minecraft servers
- FTB Stoneblock 4
