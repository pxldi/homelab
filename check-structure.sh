#!/bin/bash
# Script to check which structure is currently active and switch to the new one

set -e

echo "=== HOMELAB STRUCTURE CHECK ==="
echo ""

# Get current structure
CURRENT_PATH=$(kubectl get kustomization apps -n flux-system -o jsonpath='{.spec.path}' 2>/dev/null || echo "")
CURRENT_BRANCH=$(kubectl get gitrepository flux-system -n flux-system -o jsonpath='{.spec.ref.branch}')

echo "Current Settings:"
echo "  GitRepository Branch: $CURRENT_BRANCH"
echo "  Apps Path: $CURRENT_PATH"
echo ""

# Determine which structure
if [[ "$CURRENT_PATH" == "./flux/apps" ]]; then
    echo "✅ Currently using: OLD STRUCTURE (flux/)"
    echo ""
    echo "To switch to NEW structure:"
    echo "  1. Merge refactor branch to main"
    echo "  2. Update flux/kustomization.yaml:"
    echo "     - Comment out: infra/kustomization-flux.yaml"
    echo "     - Comment out: apps/kustomization-flux.yaml"
    echo "     - Uncomment: ../kubernetes/flux/apps-kustomizations.yaml"
    echo "  3. Push changes"
    echo "  4. Flux will automatically pick up the change"
    echo ""
elif [[ "$CURRENT_PATH" == "./kubernetes/apps" ]]; then
    echo "✅ Currently using: NEW STRUCTURE (kubernetes/)"
    echo ""
    echo "You're already on the new structure!"
else
    echo "❓ Unknown structure or not found"
fi

echo ""
echo "======================================="
echo ""

# Quick check of PVCs to verify data safety
echo "Data Safety Check (PVCs):"
PVC_COUNT=$(kubectl get pvc -A --no-headers | wc -l)
echo "  Total PVCs: $PVC_COUNT"
echo "  All should be Bound:"
kubectl get pvc -A | grep -v "Bound" | head -5 || echo "  ✅ All PVCs Bound"

echo ""
echo "======================================="
echo ""

# Test apps
echo "Quick App Health Check:"
echo "  Testing Jellyfin..."
if curl -s -o /dev/null -w "%{http_code}" https://jellyfin.pxldi.de | grep -q "302\|200"; then
    echo "  ✅ Jellyfin: OK"
else
    echo "  ❌ Jellyfin: FAILED"
fi

echo "  Testing Grafana..."
if curl -s -o /dev/null -w "%{http_code}" https://grafana.pxldi.de | grep -q "302\|200"; then
    echo "  ✅ Grafana: OK"
else
    echo "  ❌ Grafana: FAILED"
fi

echo ""
echo "======================================="
echo ""

# Show how to tell if refactor is active
echo "HOW TO VERIFY WHICH STRUCTURE IS ACTIVE:"
echo ""
echo "1. Check Kustomizations:"
echo "   kubectl get kustomizations -n flux-system"
echo ""
echo "2. Look for these names:"
echo "   OLD: infra, apps, gameservers"
echo "   NEW: network, storage, media-stack, immich, monitoring, etc."
echo ""
echo "3. Check HelmRelease labels:"
echo "   kubectl get helmrelease -A -L app.kubernetes.io/component"
echo ""
