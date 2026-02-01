#!/bin/bash
# Script to switch from old flux/ structure to new kubernetes/ structure

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     SWITCH TO NEW kubernetes/ STRUCTURE                        ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check prerequisites
echo "Step 1: Checking prerequisites..."
if [ "$(git branch --show-current)" != "main" ]; then
    echo "❌ Not on main branch. Please switch to main first:"
    echo "   git checkout main"
    exit 1
fi
echo "✅ On main branch"

# Check if refactor branch exists on remote
if ! git rev-parse --verify origin/refactor-homelab-ops-v2 &>/dev/null; then
    echo "❌ Refactor branch not found on remote"
    exit 1
fi
echo "✅ Refactor branch exists"
echo ""

# Merge refactor branch
echo "Step 2: Merging refactor branch..."
git fetch origin refactor-homelab-ops-v2
git merge origin/refactor-homelab-ops-v2 -m "Merge refactor: Switch to new kubernetes/ structure

This merges the refactor-homelab-ops-v2 branch which introduces:
- New kubernetes/ directory structure
- Minijinja templating support
- Apps organized by namespace
- Reusable components

Next step: Update flux/kustomization.yaml to use new structure"
echo "✅ Merged"
echo ""

# Update flux/kustomization.yaml
echo "Step 3: Updating flux/kustomization.yaml..."
cat > flux/kustomization.yaml << 'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - flux-system
  - sources
  # NEW: Use kubernetes/ structure
  - ../kubernetes/flux/apps-kustomizations.yaml
  # OLD: Disabled (will be removed after validation)
  # - infra/kustomization-flux.yaml
  # - apps/kustomization-flux.yaml
  # - gameservers/kustomization-flux.yaml
  - secrets/kustomization-flux.yaml
EOF
echo "✅ Updated"
echo ""

# Commit the change
echo "Step 4: Committing changes..."
git add flux/kustomization.yaml
git commit -m "chore: switch to kubernetes/ structure

Updated flux/kustomization.yaml to use new kubernetes/ structure:
- Enabled: kubernetes/flux/apps-kustomizations.yaml
- Disabled (commented out): old flux/infra, flux/apps, flux/gameservers

Cluster will now reconcile using the new structure.
Old directories will be removed after validation."
echo "✅ Committed"
echo ""

# Push changes
echo "Step 5: Pushing to remote..."
git push origin main
echo "✅ Pushed"
echo ""

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    SWITCH COMPLETE!                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "What happens next:"
echo "  1. Flux detects the change in flux/kustomization.yaml"
echo "  2. Flux starts reconciling the new kubernetes/ structure"
echo "  3. This may take 5-10 minutes"
echo ""
echo "Monitor with:"
echo "  watch flux get kustomizations -A"
echo "  kubectl logs -n flux-system deployment/flux-controller -f"
echo ""
echo "Verify switch:"
echo "  ./check-structure.sh"
echo ""
echo "After successful switch:"
echo "  1. Verify all apps work"
echo "  2. Remove old directories: git rm -r flux/infra flux/apps flux/gameservers"
echo "  3. Commit cleanup"
echo ""
