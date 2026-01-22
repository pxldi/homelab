# Homelab

![Kubernetes](https://img.shields.io/badge/kubernetes-v1.31-blue?logo=kubernetes)
![Talos](https://img.shields.io/badge/talos-v1.8-orange?logo=linux)
![Flux](https://img.shields.io/badge/flux-v2-purple?logo=flux)

Homelab running on Kubernetes Talos Linux, managed by Flux CD and Renovate.

## Stack

- **OS**: [Talos Linux](https://www.talos.dev/) - Immutable Kubernetes OS
- **GitOps**: [Flux CD](https://fluxcd.io/) - Continuous delivery
- **Secrets**: [SOPS](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age) - Encrypted secrets
- **Backup**: [Backblaze B2](https://www.backblaze.com/b2/cloud-storage.html) - Offsite backups

## TODO: More doc