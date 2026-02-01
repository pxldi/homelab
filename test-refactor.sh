#!/bin/bash
# Test script for refactor migration
# This creates a parallel test environment without affecting your current setup

set -e

echo "=== Homelab Refactor Test Script ==="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Validate flux-local
echo -e "${YELLOW}Step 1: Checking for flux-local...${NC}"
if command -v flux-local &> /dev/null; then
    echo -e "${GREEN}✓ flux-local found${NC}"
    echo "Running flux-local check..."
    flux-local check kubernetes/ || echo -e "${RED}✗ Validation failed${NC}"
else
    echo -e "${YELLOW}⚠ flux-local not found${NC}"
    echo "Install with: pip install flux-local"
fi
echo ""

# Step 2: Check cluster connectivity
echo -e "${YELLOW}Step 2: Checking cluster connectivity...${NC}"
if kubectl get nodes &> /dev/null; then
    echo -e "${GREEN}✓ Cluster connected${NC}"
    kubectl get nodes
else
    echo -e "${RED}✗ Cannot connect to cluster${NC}"
    exit 1
fi
echo ""

# Step 3: Create test GitRepository
echo -e "${YELLOW}Step 3: Creating test GitRepository...${NC}"
# Get the current git remote to determine the repo URL
REPO_URL=$(git config --get remote.origin.url)
REPO_URL=${REPO_URL%.git}  # Remove .git if present
REPO_URL=${REPO_URL/git@github.com:/https:\/\/github.com\/}  # Convert to HTTPS

cat << EOF | kubectl apply -f -
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: flux-system-test
  namespace: flux-system
spec:
  interval: 1m
  url: ${REPO_URL}
  ref:
    branch: refactor-homelab-ops-v2
EOF

echo -e "${GREEN}✓ Test GitRepository created${NC}"
echo ""

# Step 4: Create test Flux Kustomization
echo -e "${YELLOW}Step 4: Creating test Kustomization...${NC}"
cat << 'EOF' | kubectl apply -f -
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps-test
  namespace: flux-system
spec:
  interval: 5m
  path: ./kubernetes
  prune: false  # IMPORTANT: Don't delete resources!
  sourceRef:
    kind: GitRepository
    name: flux-system-test
  postBuild:
    substitute:
      DOMAIN: "pxldi.de"
      TIMEZONE: "Europe/Berlin"
      LONGHORN: "longhorn"
      LONGHORN_DUAL: "longhorn-dual-disk"
      LONGHORN_SINGLE: "longhorn-single-replica"
EOF

echo -e "${GREEN}✓ Test Kustomization created${NC}"
echo ""

# Step 5: Wait and check status
echo -e "${YELLOW}Step 5: Waiting for reconciliation (30s)...${NC}"
sleep 30

echo ""
echo -e "${YELLOW}Step 6: Checking test Kustomization status...${NC}"
kubectl get kustomization apps-test -n flux-system
echo ""

echo -e "${YELLOW}Step 7: Checking for HelmReleases...${NC}"
kubectl get helmreleases -A | head -20
echo ""

echo -e "${YELLOW}Step 8: Checking PVCs...${NC}"
kubectl get pvc -A | grep -E "(media-stack|immich)" || echo "No PVCs found yet"
echo ""

echo -e "${GREEN}=== Test Complete ===${NC}"
echo ""
echo "Next steps:"
echo "1. Check for errors: kubectl logs -n flux-system deployment/flux-operator -f"
echo "2. Verify apps are accessible"
echo "3. If everything works, merge refactor branch"
echo "4. If not, clean up: ./cleanup-test.sh"
echo ""
