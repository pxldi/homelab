#!/bin/bash
# Test script for refactor migration - Fixed version
# This tests the kubernetes/ structure properly

set -e

echo "=== Homelab Refactor Test Script (Fixed) ==="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Step 1: Validate flux-local
echo -e "${YELLOW}Step 1: Checking for flux-local...${NC}"
if command -v flux-local &> /dev/null; then
    echo -e "${GREEN}✓ flux-local found${NC}"
    echo "Running flux-local test..."
    flux-local test kubernetes/ 2>&1 | tail -5 || echo -e "${RED}✗ Validation failed${NC}"
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
# This tests the NEW workflow where we use kubernetes/flux structure
echo -e "${YELLOW}Step 4: Creating test Kustomization for kubernetes/flux...${NC}"
cat << 'EOF' | kubectl apply -f -
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps-test
  namespace: flux-system
spec:
  interval: 5m
  path: ./kubernetes/flux
  prune: false  # IMPORTANT: Don't delete resources during testing!
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
echo -e "${BLUE}Note: Testing path ./kubernetes/flux which includes apps-kustomizations.yaml${NC}"
echo ""

# Step 5: Wait for GitRepository to be ready
echo -e "${YELLOW}Step 5: Waiting for GitRepository to be ready (15s)...${NC}"
sleep 15
kubectl get gitrepository flux-system-test -n flux-system
echo ""

# Step 6: Wait for initial reconciliation
echo -e "${YELLOW}Step 6: Waiting for initial reconciliation (30s)...${NC}"
sleep 30

echo ""
echo -e "${YELLOW}Step 7: Checking test Kustomization status...${NC}"
kubectl get kustomization apps-test -n flux-system
echo ""

# Step 8: Check for child Kustomizations
echo -e "${YELLOW}Step 8: Checking for child Kustomizations...${NC}"
echo "Expected child Kustomizations:"
echo "  - network"
echo "  - storage"
echo "  - kube-system"
echo "  - media-stack"
echo "  - immich"
echo "  - monitoring"
echo "  - default"
echo "  - selfhosted"
echo "  - games"
echo ""
kubectl get kustomizations -A | grep -E "(network|storage|kube-system|media-stack|immich|monitoring|default|selfhosted|games)" || echo -e "${RED}No child Kustomizations found - checking logs...${NC}"
echo ""

# Step 9: Check for HelmReleases
echo -e "${YELLOW}Step 9: Checking for HelmReleases...${NC}"
kubectl get helmreleases -A | wc -l | xargs echo "Total HelmReleases:"
kubectl get helmreleases -A | tail -10
echo ""

# Step 10: Check PVCs
echo -e "${YELLOW}Step 10: Checking PVCs...${NC}"
kubectl get pvc -A | grep -E "(media-stack|immich)" || echo "No PVCs found"
echo ""

echo -e "${GREEN}=== Test Complete ===${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo "1. GitRepository: flux-system-test"
echo "2. Kustomization: apps-test (points to ./kubernetes/flux)"
echo ""
echo "Next steps:"
echo "1. Check child Kustomization status:"
echo "   kubectl get kustomizations -A"
echo ""
echo "2. Check for errors in logs:"
echo "   kubectl logs -n flux-system deployment/kustomize-controller -f"
echo ""
echo "3. If child Kustomizations are READY=True, the refactor works!"
echo ""
echo "4. Clean up when done:"
echo "   ./cleanup-test.sh"
echo ""
