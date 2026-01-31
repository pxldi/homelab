# Homelab Refactor Plan: Migrate to ishioni/homelab-ops Structure

## Overview
Migrate from current `flux/` structure to `kubernetes/` structure inspired by [ishioni/homelab-ops](https://github.com/ishioni/homelab-ops).

**Branch:** `refactor/homelab-ops-structure`
**Date:** 2025-01-31

---

## Data Safety Guarantee

### What's Safe
✅ **All Longhorn PVs and data** - Stored independently in Longhorn backend
✅ **Application configurations** - Persisted in PVCs
✅ **Secrets** - SOPS encrypted, will be migrated

### Why It's Safe
- PVs are bound to PVCs by `(namespace, name)` tuple
- We're preserving namespace and PVC names exactly
- Flux will see changes as "updates" not "recreate"
- Longhorn volumes are not affected by Kubernetes manifest changes

### Safety Measures
1. **Backup verification** - Check Longhorn recurring jobs before migration
2. **Incremental migration** - One namespace at a time
3. **Validation** - `flux-local` diff on each step
4. **Rollback plan** - Git revert if needed

---

## New Directory Structure

```
homelab/
├── kubernetes/                          # NEW: Root for all k8s resources
│   ├── flux/                            # Flux system configuration
│   │   ├── cluster/                     # Cluster configuration
│   │   └── config/                      # Flux config
│   ├── apps/                            # Apps organized by NAMESPACE
│   │   ├── media-stack/                 # Namespace: media-stack
│   │   │   ├── jellyfin/
│   │   │   │   ├── app/
│   │   │   │   │   ├── helmrelease.yaml
│   │   │   │   │   ├── pvc.yaml         # If PVC needed
│   │   │   │   │   ├── secret.yaml      # ExternalSecret if needed
│   │   │   │   │   └── configmap.yaml   # If ConfigMap needed
│   │   │   │   └── ks.yaml              # Flux Kustomization per app
│   │   │   ├── radarr/
│   │   │   ├── sonarr/
│   │   │   └── sabnzbd/
│   │   ├── immich/                      # Namespace: immich
│   │   ├── monitoring/                  # Namespace: monitoring
│   │   ├── default/                     # Namespace: default
│   │   ├── network/                     # Namespace: network (new)
│   │   ├── database/                    # Namespace: database (new for CNPG)
│   │   ├── selfhosted/                  # Namespace: selfhosted
│   │   └── kube-system/                 # Namespace: kube-system
│   ├── components/                      # NEW: Reusable components
│   │   ├── namespace/                   # Namespace component
│   │   ├── pvc/                         # PVC component
│   │   ├── alerts/                      # PrometheusRule component
│   │   ├── volsync/                     # VolSync component (if used)
│   │   └── authentik-proxy/             # Auth component (if needed)
│   └── .minijinja.toml                  # NEW: Templating configuration
├── flux/                                # OLD: Will be deprecated after migration
├── talos/                               # Unchanged
├── bootstrap/                           # Unchanged
├── .sops.yaml                           # Unchanged
└── renovate.json                        # Unchanged
```

---

## Key Changes

### 1. Directory Organization
| Before | After |
|--------|-------|
| `flux/apps/media-stack/jellyfin.yaml` | `kubernetes/apps/media-stack/jellyfin/app/helmrelease.yaml` |
| `flux/apps/namespaces/` | `kubernetes/components/namespace/` |
| `flux/infra/` | `kubernetes/components/` (reusable) |

### 2. File Naming
| Before | After |
|--------|-------|
| `kustomization.yaml` | `ks.yaml` (for Flux Kustomizations) |
| `kustomization-flux.yaml` | `ks.yaml` (unified) |
| `helmrelease.yaml` | `helmrelease.yaml` (same) |

### 3. HelmRelease Syntax

#### Before:
```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: immich
  namespace: immich
spec:
  interval: 1h
  chart:
    spec:
      chart: immich
      version: "25.23.0"
      sourceRef:
        kind: HelmRepository
        name: truecharts
        namespace: flux-system
  values:
    # ... values
```

#### After:
```yaml
---
# yaml-language-server: $schema=https://raw.githubusercontent.com/bjw-s-labs/helm-charts/app-template/schemas/helmrelease-helm-v2.schema.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: immich
spec:
  chartRef:
    kind: OCIRepository
    name: immich
  interval: 30m
  values:
    controllers:
      main:
        containers:
          main:
            image:
              repository: ghcr.io/immich-app/immich-server
              tag: v2.5.2
    service:
      main:
        ports:
          http:
            port: 8080
    route:
      main:
        hostnames: ["${HOSTNAME}"]
        parentRefs:
          - name: traefik
            namespace: network
```

### 4. Flux Kustomization Pattern

#### Before:
```yaml
# flux/apps/kustomization-flux.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 5m
  path: ./flux/apps
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
  decryption:
    provider: sops
    secretRef:
      name: sops-age
```

#### After:
```yaml
# kubernetes/apps/media-stack/jellyfin/ks.yaml
---
# yaml-language-server: $schema=https://crd.movishell.pl/kustomize.toolkit.fluxcd.io/kustomization_v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: jellyfin
  namespace: flux-system
spec:
  commonMetadata:
    labels:
      app.kubernetes.io/name: jellyfin
  interval: 30m
  path: ./kubernetes/apps/media-stack/jellyfin/app
  prune: true
  sourceRef:
    kind: GitRepository
    name: homelab
    namespace: flux-system
  targetNamespace: media-stack
  wait: true
  postBuild:
    substitute:
      APP: jellyfin
      HOSTNAME: jellyfin.${DOMAIN}
```

### 5. Minijinja Templating

Enable variable substitution across all manifests:

```toml
# .minijinja.toml
[context]
# Global variables available in all manifests
DOMAIN = "pxldi.de"
TIMEZONE = "Europe/Berlin"
CONFIG_TRUENAS_IP = "10.0.0.100"  # Example

[context.storage]
LONGHORN_DEFAULT = "longhorn"
LONGHORN_DUAL = "longhorn-dual-disk"
LONGHORN_SINGLE = "longhorn-single-replica"
```

Usage in manifests:
```yaml
host: ${APP}.${DOMAIN}              # → jellyfin.pxldi.de
storageClass: ${LONGHORN_DUAL}      # → longhorn-dual-disk
tz: ${TIMEZONE}                     # → Europe/Berlin
```

### 6. Components Pattern

Instead of repeating namespace definitions:

```yaml
# kubernetes/components/namespace/kustomization.yaml
---
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
```

```yaml
# kubernetes/apps/media-stack/jellyfin/ks.yaml
components:
  - ../../../../components/namespace  # Reuse!
  - ../../../../components/alerts     # Add monitoring
```

---

## Migration Steps

### Phase 0: Pre-Migration Preparation ✅
- [x] Create feature branch
- [ ] Verify Longhorn backups are working
- [ ] Document all current apps and namespaces
- [ ] Install/configure Minijinja (if not already in Flux)

### Phase 1: Foundation
- [ ] Create new `kubernetes/` directory structure
- [ ] Create `kubernetes/components/` with reusable components
- [ ] Set up `.minijinja.toml` with global variables
- [ ] Migrate Flux configuration to `kubernetes/flux/`
- [ ] Update root `flux/kustomization.yaml` to point to new structure

### Phase 2: Infrastructure Components (NO APPS YET)
- [ ] Migrate Traefik → `kubernetes/apps/network/traefik/`
- [ ] Migrate Longhorn → `kubernetes/apps/storage/longhorn/`
- [ ] Migrate cert-manager → `kubernetes/apps/network/cert-manager/`
- [ ] Migrate Cilium → `kubernetes/apps/network/cilium/`
- [ ] Migrate MetalLB → `kubernetes/apps/network/metallb/`
- [ ] Migrate Tailscale → `kubernetes/apps/network/tailscale/`
- [ ] Migrate Authelia → `kubernetes/apps/security/authelia/`
- [ ] Create `kubernetes/components/` for:
  - [ ] namespace component
  - [ ] pvc component
  - [ ] alerts component
- [ ] Update HelmRepository sources → `kubernetes/flux/sources/`
- [ ] Validate infrastructure still works

### Phase 3: Namespace-by-Namespace Migration
For each namespace, in order of dependency:

#### 3.1: monitoring namespace
- [ ] Migrate kube-prometheus-stack
- [ ] Validate: Grafana dashboards, Prometheus targets

#### 3.2: network namespace
- [ ] Migrate any network services (Pi-hole, etc.)

#### 3.3: media-stack namespace
- [ ] Migrate Jellyfin
- [ ] Migrate Radarr
- [ ] Migrate Sonarr
- [ ] Migrate SABnzbd
- [ ] Validate: All apps accessible, data intact

#### 3.4: immich namespace
- [ ] Migrate Immich
- [ ] Validate: Photos accessible, database connected

#### 3.5: other namespaces
- [ ] nextcloud
- [ ] home-assistant
- [ ] tandoor
- [ ] freshrss
- [ ] obsidian-sync
- [ ] pihole
- [ ] searxng
- [ ] glances
- [ ] dashboard

### Phase 4: Gameservers
- [ ] Migrate Minecraft servers
- [ ] Validate: Servers accessible, world data intact

### Phase 5: Cleanup
- [ ] Remove old `flux/` directory (or archive as `flux.old/`)
- [ ] Update CLAUDE.md with new structure
- [ ] Update Taskfile.yaml commands
- [ ] Test full cluster reconciliation

### Phase 6: Testing & Validation
- [ ] Run `task validate`
- [ ] Check all Flux Kustomizations are healthy
- [ ] Verify all apps are accessible
- [ ] Check Longhorn volumes are still attached
- [ ] Verify backup jobs still work

---

## Namespace Mapping

| Current Namespace | New Path | Apps |
|-------------------|----------|------|
| `media-stack` | `kubernetes/apps/media-stack/` | jellyfin, radarr, sonarr, sabnzbd |
| `immich` | `kubernetes/apps/immich/` | immich |
| `monitoring` | `kubernetes/apps/monitoring/` | kube-prometheus-stack |
| `pihole` | `kubernetes/apps/network/` | pihole |
| `home-assistant` | `kubernetes/apps/default/` | home-assistant |
| `nextcloud` | `kubernetes/apps/selfhosted/` | nextcloud |
| `tandoor` | `kubernetes/apps/selfhosted/` | tandoor |
| `freshrss` | `kubernetes/apps/selfhosted/` | freshrss |
| `obsidian-sync` | `kubernetes/apps/selfhosted/` | obsidian-sync |
| `searxng` | `kubernetes/apps/selfhosted/` | searxng |
| `glances` | `kubernetes/apps/monitoring/` | glances |

---

## App Migration Template

For each app, the migration follows this pattern:

```bash
# Example: Migrating Jellyfin

# 1. Create new directory structure
mkdir -p kubernetes/apps/media-stack/jellyfin/app

# 2. Create helmrelease.yaml (convert syntax)
#    - Use chartRef instead of chart.spec
#    - Update values structure if using bjw-s app-template
#    - Add Minijinja variables

# 3. Create ks.yaml (Flux Kustomization)
#    - Add namespace as targetNamespace
#    - Add commonMetadata labels
#    - Add postBuild substitute variables
#    - Add dependency chain

# 4. Create pvc.yaml if needed (often not needed if in chart values)

# 5. Create secret.yaml if using ExternalSecret

# 6. Create namespace-level ks.yaml
#    kubernetes/apps/media-stack/ks.yaml
#    - Lists all apps in namespace
#    - Adds common components

# 7. Validate with flux-local
flux-local diff kubernetes/apps/media-stack/jellyfin

# 8. Commit and test
```

### Detailed Migration Example: Jellyfin

#### Current Structure:
```
flux/apps/media-stack/
├── jellyfin.yaml       # HelmRelease
├── radarr.yaml
├── sonarr.yaml
├── sabnzbd.yaml
├── download-pvc.yaml   # PVC
├── media-pvc.yaml      # PVC
└── kustomization.yaml
```

#### New Structure:
```
kubernetes/apps/media-stack/
├── ks.yaml                              # Namespace-level Flux Kustomization
├── jellyfin/
│   └── app/
│       ├── helmrelease.yaml             # Converted HelmRelease
│       └── ks.yaml                      # App-level Flux Kustomization
├── radarr/
│   └── app/
│       ├── helmrelease.yaml
│       └── ks.yaml
├── sonarr/
│   └── app/
│       ├── helmrelease.yaml
│       └── ks.yaml
└── sabnzbd/
    └── app/
        ├── helmrelease.yaml
        └── ks.yaml
```

#### Example: `kubernetes/apps/media-stack/jellyfin/app/ks.yaml`
```yaml
---
# yaml-language-server: $schema=https://crd.movishell.pl/kustomize.toolkit.fluxcd.io/kustomization_v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: jellyfin
  namespace: flux-system
spec:
  commonMetadata:
    labels:
      app.kubernetes.io/name: jellyfin
      app.kubernetes.io/component: app
  interval: 30m
  path: ./kubernetes/apps/media-stack/jellyfin/app
  prune: true
  sourceRef:
    kind: GitRepository
    name: homelab
    namespace: flux-system
  targetNamespace: media-stack
  wait: true
  postBuild:
    substitute:
      APP: jellyfin
      HOSTNAME: jellyfin.${DOMAIN}
      VOLSYNC_CLAIM: jellyfin-config
```

#### Example: `kubernetes/apps/media-stack/ks.yaml`
```yaml
---
# yaml-language-server: $schema=https://crd.movishell.pl/kustomize.toolkit.fluxcd.io/kustomization_v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: media-stack
  namespace: flux-system
spec:
  commonMetadata:
    labels:
      app.kubernetes.io/name: media-stack
  interval: 30m
  path: ./kubernetes/apps/media-stack
  prune: true
  sourceRef:
    kind: GitRepository
    name: homelab
    namespace: flux-system
  dependsOn:
    - name: infra
  postBuild:
    substitute:
      NAMESPACE: media-stack
```

---

## Validation Commands

```bash
# Check Flux reconciliation
flux get kustomizations -A
flux get helmreleases -A

# Check cluster health
kubectl get pods -A
kubectl get pvc -A

# Check Longhorn volumes
kubectl get pvc -n media-stack
kubectl get pv -A

# Validate syntax
task validate

# Diff changes
flux-local diff kubernetes/
```

---

## Rollback Plan

If anything goes wrong:

```bash
# 1. Stop reconciliation
flux suspend kustomization flux-system -n flux-system

# 2. Revert to last known good state
git revert HEAD

# 3. Resume reconciliation
flux resume kustomization flux-system -n flux-system

# 4. Force sync if needed
flux reconcile kustomization flux-system -n flux-system
```

---

## Open Questions

1. **Minijinja setup**: Does current Flux version support Minijinja? Need to verify.
2. **External Secrets**: Are we using ExternalSecret operator? If so, migrate to `kubernetes/apps/security/`.
3. **OCI Repositories**: Target uses OCIRepository for charts. Our current HelmRepository approach still works but OCI is more modern.
4. **Network namespace**: Should we consolidate all networking (Traefik, Pi-hole) into a `network` namespace?

---

## Timeline Estimate

- Phase 0: 30 minutes
- Phase 1: 2 hours (foundation work)
- Phase 2: 1 hour (infrastructure)
- Phase 3: 4-6 hours (all apps)
- Phase 4: 1 hour (gameservers)
- Phase 5: 1 hour (cleanup)
- Phase 6: 1 hour (testing)

**Total: ~10-12 hours** (can be done in multiple sessions)

---

## References

- [ishioni/homelab-ops](https://github.com/ishioni/homelab-ops)
- [bjw-s helm-charts](https://github.com/bjw-s/helm-charts)
- [Flux Kustomization docs](https://fluxcd.io/flux/components/kustomize/)
- [Minijinja for Flux](https://fluxcd.io/flux/components/kustomize/kustomizations/#variable-substitution)
