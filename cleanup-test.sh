#!/bin/bash
# Cleanup script to remove test resources

set -e

echo "=== Cleaning up test resources ==="

# Delete test Kustomization
echo "Deleting test Kustomization..."
kubectl delete kustomization apps-test -n flux-system --ignore-not-found=true

# Delete test GitRepository
echo "Deleting test GitRepository..."
kubectl delete gitrepository flux-system-test -n flux-system --ignore-not-found=true

echo -e "\n✓ Cleanup complete"
echo ""
echo "Your cluster is now running only the original flux/ structure"
