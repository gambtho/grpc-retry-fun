# AKS Deployment Pipeline - Implementation Summary

## Overview
Complete AKS deployment pipeline created for the gRPC retry fun application with security best practices and production-ready configuration.

## Files Created

### 1. Dockerfile
- **Location**: `./Dockerfile`
- **Type**: Multi-stage build
- **Base Images**: 
  - Build: `golang:1.19`
  - Runtime: `gcr.io/distroless/static-debian11:nonroot`
- **Image Size**: 20.3MB (4.45MB compressed)
- **Security Features**:
  - Non-root user (UID 65532)
  - Distroless base (minimal attack surface)
  - Static binary compilation
  - Optimized for caching

### 2. Kubernetes Manifests (`deploy/kubernetes/`)

#### namespace.yaml
- Creates the `yet-another` namespace

#### deployment.yaml
- **Replicas**: 2 (initial)
- **Port**: 50051 (gRPC)
- **Image**: Dynamic (replaced with ACR name during deployment)
- **Security Context**:
  - `runAsNonRoot: true`
  - `runAsUser: 65532`
  - `readOnlyRootFilesystem: true`
  - `allowPrivilegeEscalation: false`
  - All capabilities dropped
  - seccomp RuntimeDefault profile
- **Resource Limits**:
  - Requests: 100m CPU, 64Mi memory
  - Limits: 200m CPU, 128Mi memory
- **Health Probes**:
  - Liveness: TCP check on port 50051
  - Readiness: TCP check on port 50051
  - Startup: TCP check with 30 failure threshold

#### service.yaml
- **Type**: ClusterIP
- **Port**: 50051
- **Protocol**: TCP

#### hpa.yaml (Horizontal Pod Autoscaler)
- **Min Replicas**: 2
- **Max Replicas**: 10
- **Targets**:
  - CPU: 70% utilization
  - Memory: 80% utilization
- **Scale Behaviors**:
  - Scale-up: Fast (100% increase / 30s)
  - Scale-down: Conservative (50% decrease / 60s, 5min stabilization)

#### pdb.yaml (Pod Disruption Budget)
- **Min Available**: 1 pod
- Ensures high availability during voluntary disruptions

### 3. GitHub Actions Workflow
- **Location**: `.github/workflows/deploy-to-aks.yml`
- **Trigger**: `workflow_dispatch` only (manual trigger)
- **Inputs**:
  - `cluster-name` (default: headlamp-thgamble)
  - `resource-group` (default: thgamble)
  - `namespace` (default: yet-another)
  - `subscription-id` (default: d98169bc-2d4a-491b-98cb-b69cbf002eb0)
- **Authentication**: OIDC with azure/login@v2
- **Steps**:
  1. Checkout code
  2. Azure login with OIDC
  3. Discover ACR from resource group
  4. Build Docker image
  5. Login to ACR
  6. Push image to ACR (tags: 1.0 and latest)
  7. Set AKS context
  8. Create namespace if needed
  9. Substitute ACR name in manifests
  10. Deploy to AKS
  11. Wait for rollout
  12. Verify deployment

### 4. Documentation
- **deploy/README.md**: Comprehensive deployment guide
  - Overview and architecture
  - Resource descriptions
  - Deployment methods (GitHub Actions and manual)
  - Verification steps
  - Monitoring commands
  - Troubleshooting guide
  - Security features

### 5. Build Optimization
- **.dockerignore**: Excludes unnecessary files from build context
  - Git files, documentation, IDE configs
  - Deploy files, artifacts
  - Reduces build context size

## Configuration Details

### AKS Configuration
- **Cluster**: headlamp-thgamble
- **Resource Group**: thgamble
- **Namespace**: yet-another
- **Tenant ID**: b06f66c5-f30b-4797-8dec-52cc6568e9aa
- **Subscription ID**: d98169bc-2d4a-491b-98cb-b69cbf002eb0

### Application Details
- **Name**: grpc-retry-fun
- **Port**: 50051
- **Protocol**: gRPC
- **Language**: Go 1.19
- **Module**: helloworld

### Security Best Practices Implemented

1. **Container Security**:
   - Distroless base image (no shell, minimal packages)
   - Non-root user execution
   - Read-only root filesystem
   - No privilege escalation
   - All capabilities dropped
   - Seccomp profile enabled

2. **Resource Management**:
   - CPU and memory limits defined
   - Prevents resource exhaustion
   - HPA for automatic scaling

3. **High Availability**:
   - Minimum 2 replicas
   - Pod Disruption Budget
   - Health probes for reliability

4. **Access Control**:
   - ClusterIP service (internal only)
   - Namespace isolation
   - OIDC authentication for deployments

## Deployment Flow

```
GitHub Actions Trigger (workflow_dispatch)
  ↓
Azure OIDC Login
  ↓
Discover ACR from Resource Group
  ↓
Build Docker Image (grpc-retry-fun:1.0)
  ↓
Push to Azure Container Registry
  ↓
Set AKS Context
  ↓
Apply Kubernetes Manifests
  ↓
Wait for Rollout & Verify
```

## Prerequisites for Deployment

### GitHub Secrets Required:
1. `AZURE_CLIENT_ID` - Azure service principal client ID
2. `AZURE_TENANT_ID` - Azure tenant ID

### Azure Permissions Required:
1. AcrPush role on ACR
2. Azure Kubernetes Service Cluster User Role on AKS

## Validation Results

✅ Dockerfile builds successfully (image tag: 1.0)
✅ All Kubernetes manifests are valid YAML
✅ Security best practices implemented
✅ GitHub Actions workflow configured
✅ Documentation complete

## Next Steps

1. **Configure GitHub Secrets**:
   ```bash
   # In GitHub repo settings → Secrets and variables → Actions
   # Add: AZURE_CLIENT_ID and AZURE_TENANT_ID
   ```

2. **Run First Deployment**:
   - Go to Actions tab
   - Select "Deploy to AKS"
   - Click "Run workflow"
   - Use default values
   - Monitor deployment

3. **Verify Deployment**:
   ```bash
   kubectl get all -n yet-another -l app=grpc-retry-fun
   ```

## Compliance

- ✅ Image tag is `1.0` (as required)
- ✅ Service type is `ClusterIP` (as required)
- ✅ Namespace is `yet-another` (as required)
- ✅ Cluster configuration matches requirements
- ✅ GitHub Actions uses workflow_dispatch trigger only
- ✅ OIDC authentication implemented
- ✅ All files in correct directories

## Notes

- The deployment workflow automatically discovers the ACR name from the resource group
- Image is tagged with both `1.0` and `latest` for flexibility
- Manifests use `${ACR_NAME}` placeholder which is replaced during deployment
- TCP health probes are used (gRPC health check service can be added later)
- HPA requires metrics-server to be installed in the cluster
