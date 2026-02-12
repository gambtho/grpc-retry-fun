#!/bin/bash
#
# Validation script for AKS deployment artifacts
# Run this script to verify all required files and configurations
#

set -e

echo "============================================"
echo "AKS Deployment Validation Script"
echo "Project: grpc-retry-fun"
echo "============================================"
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success_count=0
fail_count=0

check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $description: $file"
        ((success_count++))
        return 0
    else
        echo -e "${RED}✗${NC} $description: $file (NOT FOUND)"
        ((fail_count++))
        return 1
    fi
}

check_directory() {
    local dir=$1
    local description=$2
    
    if [ -d "$dir" ]; then
        echo -e "${GREEN}✓${NC} $description: $dir"
        ((success_count++))
        return 0
    else
        echo -e "${RED}✗${NC} $description: $dir (NOT FOUND)"
        ((fail_count++))
        return 1
    fi
}

validate_yaml() {
    local file=$1
    
    if command -v python3 &> /dev/null; then
        if python3 -c "import yaml, sys; yaml.safe_load(open('$file'))" 2>/dev/null; then
            return 0
        else
            echo -e "${RED}  Invalid YAML syntax${NC}"
            return 1
        fi
    fi
    return 0
}

echo "=== Checking Core Files ==="
check_file "Dockerfile" "Dockerfile"
check_file ".dockerignore" "Docker ignore file"

echo ""
echo "=== Checking Kubernetes Manifests ==="
check_directory "deploy/kubernetes" "Kubernetes directory"
check_file "deploy/kubernetes/deployment.yaml" "Deployment manifest"
check_file "deploy/kubernetes/service.yaml" "Service manifest"
check_file "deploy/kubernetes/configmap.yaml" "ConfigMap manifest"
check_file "deploy/kubernetes/pdb.yaml" "PodDisruptionBudget manifest"
check_file "deploy/kubernetes/networkpolicy.yaml" "NetworkPolicy manifest"

echo ""
echo "=== Validating YAML Syntax ==="
for yaml_file in deploy/kubernetes/*.yaml; do
    if [ -f "$yaml_file" ]; then
        echo -n "  Checking $yaml_file... "
        if validate_yaml "$yaml_file"; then
            echo -e "${GREEN}✓${NC}"
            ((success_count++))
        else
            ((fail_count++))
        fi
    fi
done

echo ""
echo "=== Checking CI/CD Pipeline ==="
check_file ".github/workflows/deploy-to-aks.yml" "GitHub Actions workflow"

echo ""
echo "=== Checking Documentation ==="
check_file "deploy/README.md" "Deployment documentation"
check_file "artifacts/DEPLOYMENT_SUMMARY.md" "Deployment summary"
check_file "artifacts/tool-call-checklist.md" "Tool call checklist"

echo ""
echo "=== Checking Docker Image ==="
if docker images grpc-retry-fun:1.0 --format "{{.Repository}}:{{.Tag}}" | grep -q "grpc-retry-fun:1.0"; then
    echo -e "${GREEN}✓${NC} Docker image exists: grpc-retry-fun:1.0"
    IMAGE_SIZE=$(docker images grpc-retry-fun:1.0 --format "{{.Size}}")
    echo -e "  Image size: ${YELLOW}${IMAGE_SIZE}${NC}"
    ((success_count++))
else
    echo -e "${RED}✗${NC} Docker image not found: grpc-retry-fun:1.0"
    echo -e "  Run: ${YELLOW}docker build -t grpc-retry-fun:1.0 .${NC}"
    ((fail_count++))
fi

echo ""
echo "=== Checking Application Configuration ==="

# Check if namespace is correctly set in manifests
NAMESPACE_COUNT=$(grep -r "namespace: somens" deploy/kubernetes/ 2>/dev/null | wc -l)
if [ "$NAMESPACE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Namespace 'somens' configured ($NAMESPACE_COUNT files)"
    ((success_count++))
else
    echo -e "${RED}✗${NC} Namespace 'somens' not found in manifests"
    ((fail_count++))
fi

# Check if port 50051 is configured
PORT_COUNT=$(grep -r "50051" deploy/kubernetes/ 2>/dev/null | wc -l)
if [ "$PORT_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Port 50051 configured"
    ((success_count++))
else
    echo -e "${RED}✗${NC} Port 50051 not found in manifests"
    ((fail_count++))
fi

# Check if service type is ClusterIP
if grep -q "type: ClusterIP" deploy/kubernetes/service.yaml 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Service type is ClusterIP"
    ((success_count++))
else
    echo -e "${RED}✗${NC} Service type is not ClusterIP"
    ((fail_count++))
fi

# Check if image tag is 1.0
if grep -q "grpc-retry-fun:1.0" deploy/kubernetes/deployment.yaml 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Image tag is 1.0"
    ((success_count++))
else
    echo -e "${YELLOW}!${NC} Image tag may need updating in deployment.yaml"
fi

echo ""
echo "=== Checking Azure Configuration ==="

# Check workflow for correct cluster name
if grep -q "thgamble_dt" .github/workflows/deploy-to-aks.yml 2>/dev/null; then
    echo -e "${GREEN}✓${NC} AKS cluster name configured: thgamble_dt"
    ((success_count++))
else
    echo -e "${RED}✗${NC} AKS cluster name not found in workflow"
    ((fail_count++))
fi

# Check workflow for correct resource group
if grep -q "thgamble_dt_group" .github/workflows/deploy-to-aks.yml 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Resource group configured: thgamble_dt_group"
    ((success_count++))
else
    echo -e "${RED}✗${NC} Resource group not found in workflow"
    ((fail_count++))
fi

echo ""
echo "============================================"
echo "Validation Summary"
echo "============================================"
echo -e "Successful checks: ${GREEN}${success_count}${NC}"
echo -e "Failed checks: ${RED}${fail_count}${NC}"
echo ""

if [ $fail_count -eq 0 ]; then
    echo -e "${GREEN}✓ All validations passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Configure GitHub secrets:"
    echo "   - AZURE_CLIENT_ID"
    echo "   - AZURE_TENANT_ID"
    echo "   - AZURE_SUBSCRIPTION_ID"
    echo ""
    echo "2. Push changes to trigger deployment:"
    echo "   git add ."
    echo "   git commit -m 'deploy: Add AKS deployment pipeline'"
    echo "   git push origin main"
    echo ""
    echo "3. Monitor deployment in GitHub Actions"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some validations failed. Please fix the issues above.${NC}"
    echo ""
    exit 1
fi
