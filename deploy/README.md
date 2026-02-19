# Deployment Guide for grpc-retry-fun

This directory contains all necessary files to deploy the gRPC retry fun application to Azure Kubernetes Service (AKS).

## Overview

- **Application**: Go-based gRPC server
- **Port**: 50051
- **Image Tag**: 1.0
- **Base Image**: gcr.io/distroless/static-debian11:nonroot (distroless for security)

## Directory Structure

```
deploy/
├── kubernetes/
│   ├── namespace.yaml       # Namespace definition
│   ├── deployment.yaml      # Main application deployment
│   ├── service.yaml         # ClusterIP service
│   ├── hpa.yaml            # Horizontal Pod Autoscaler
│   └── pdb.yaml            # Pod Disruption Budget
└── README.md               # This file
```

## Kubernetes Resources

### Namespace
- **Name**: `yet-another`
- All resources are deployed to this namespace

### Deployment
- **Name**: `grpc-retry-fun`
- **Replicas**: 2 (initial)
- **Security**:
  - Runs as non-root user (UID 65532)
  - Read-only root filesystem
  - All capabilities dropped
  - seccomp profile enabled
- **Resources**:
  - Requests: 100m CPU, 64Mi memory
  - Limits: 200m CPU, 128Mi memory
- **Health Probes**:
  - Liveness probe (TCP check on port 50051)
  - Readiness probe (TCP check on port 50051)
  - Startup probe (TCP check with extended failure threshold)

### Service
- **Name**: `grpc-retry-fun`
- **Type**: ClusterIP
- **Port**: 50051 (gRPC)

### Horizontal Pod Autoscaler (HPA)
- **Min Replicas**: 2
- **Max Replicas**: 10
- **Metrics**:
  - CPU: 70% utilization target
  - Memory: 80% utilization target
- **Scale-up**: Fast (up to 100% increase every 30s)
- **Scale-down**: Conservative (up to 50% decrease every 60s, 5min stabilization)

### Pod Disruption Budget (PDB)
- **Min Available**: 1
- Ensures at least 1 pod is always available during voluntary disruptions

## Deployment Methods

### Method 1: GitHub Actions (Recommended)

The repository includes a GitHub Actions workflow (`.github/workflows/deploy-to-aks.yml`) that automates the entire deployment process.

**Prerequisites**:
1. Configure GitHub secrets:
   - `AZURE_CLIENT_ID`: Azure service principal client ID
   - `AZURE_TENANT_ID`: Azure tenant ID (b06f66c5-f30b-4797-8dec-52cc6568e9aa)

2. Ensure the service principal has:
   - AcrPush role on the Azure Container Registry
   - Azure Kubernetes Service Cluster User Role on the AKS cluster

**To Deploy**:
1. Go to the "Actions" tab in your GitHub repository
2. Select "Deploy to AKS" workflow
3. Click "Run workflow"
4. Use default values or customize:
   - Cluster name: `headlamp-thgamble`
   - Resource group: `thgamble`
   - Namespace: `yet-another`
   - Subscription ID: `d98169bc-2d4a-491b-98cb-b69cbf002eb0`
5. Click "Run workflow" button

The workflow will:
- Build the Docker image
- Push to Azure Container Registry
- Deploy to AKS cluster
- Verify the deployment

### Method 2: Manual Deployment

**Prerequisites**:
1. Azure CLI installed and configured
2. kubectl installed
3. Docker installed
4. Access to AKS cluster

**Steps**:

```bash
# 1. Login to Azure
az login

# 2. Set subscription
az account set --subscription d98169bc-2d4a-491b-98cb-b69cbf002eb0

# 3. Get ACR name
ACR_NAME=$(az acr list --resource-group thgamble --query "[0].name" -o tsv)

# 4. Build and push Docker image
docker build -t ${ACR_NAME}.azurecr.io/grpc-retry-fun:1.0 .
az acr login --name ${ACR_NAME}
docker push ${ACR_NAME}.azurecr.io/grpc-retry-fun:1.0

# 5. Get AKS credentials
az aks get-credentials --resource-group thgamble --name headlamp-thgamble

# 6. Substitute ACR name in manifests
find deploy/kubernetes/ -type f -name "*.yaml" -exec sed -i "s/\${ACR_NAME}/${ACR_NAME}/g" {} \;

# 7. Deploy to Kubernetes
kubectl apply -f deploy/kubernetes/ -n yet-another

# 8. Verify deployment
kubectl get all -n yet-another -l app=grpc-retry-fun
```

## Verification

After deployment, verify the application is running:

```bash
# Check deployment status
kubectl get deployment grpc-retry-fun -n yet-another

# Check pods
kubectl get pods -n yet-another -l app=grpc-retry-fun

# Check service
kubectl get service grpc-retry-fun -n yet-another

# Check HPA
kubectl get hpa grpc-retry-fun-hpa -n yet-another

# View logs
kubectl logs -n yet-another -l app=grpc-retry-fun --tail=50
```

## Testing the gRPC Service

Since the service is ClusterIP, you need to access it from within the cluster:

```bash
# Port forward to test locally
kubectl port-forward -n yet-another service/grpc-retry-fun 50051:50051

# In another terminal, test with grpcurl (if installed)
grpcurl -plaintext localhost:50051 list

# Or create a test pod
kubectl run grpc-test -n yet-another --rm -it --image=fullstorydev/grpcurl:latest -- \
  -plaintext grpc-retry-fun:50051 list
```

## Monitoring

Monitor the application using kubectl commands:

```bash
# Watch pod status
kubectl get pods -n yet-another -l app=grpc-retry-fun -w

# View detailed pod information
kubectl describe pod -n yet-another -l app=grpc-retry-fun

# Check resource usage
kubectl top pods -n yet-another -l app=grpc-retry-fun

# View HPA metrics
kubectl get hpa grpc-retry-fun-hpa -n yet-another -w
```

## Troubleshooting

### Pods not starting
```bash
# Check pod events
kubectl describe pod -n yet-another -l app=grpc-retry-fun

# Check logs
kubectl logs -n yet-another -l app=grpc-retry-fun --tail=100
```

### Image pull errors
```bash
# Verify ACR integration
az aks check-acr --resource-group thgamble --name headlamp-thgamble --acr ${ACR_NAME}

# Check if image exists
az acr repository show --name ${ACR_NAME} --repository grpc-retry-fun
```

### HPA not scaling
```bash
# Check metrics server
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml

# Check HPA status
kubectl describe hpa grpc-retry-fun-hpa -n yet-another
```

## Updating the Application

To update the application:

1. Make code changes
2. Trigger the GitHub Actions workflow (it will rebuild and redeploy)
3. Or manually:
   ```bash
   docker build -t ${ACR_NAME}.azurecr.io/grpc-retry-fun:1.0 .
   docker push ${ACR_NAME}.azurecr.io/grpc-retry-fun:1.0
   kubectl rollout restart deployment/grpc-retry-fun -n yet-another
   ```

## Cleanup

To remove the deployment:

```bash
# Delete all resources
kubectl delete -f deploy/kubernetes/ -n yet-another

# Or delete the namespace (removes everything)
kubectl delete namespace yet-another
```

## Security Features

This deployment implements several security best practices:

1. **Distroless base image**: Minimal attack surface
2. **Non-root user**: Application runs as UID 65532
3. **Read-only root filesystem**: Prevents runtime modifications
4. **Dropped capabilities**: All Linux capabilities are dropped
5. **Seccomp profile**: Runtime security with RuntimeDefault profile
6. **Resource limits**: Prevents resource exhaustion
7. **Pod Security Standards**: Complies with restricted PSS

## Configuration

### Environment Variables
Currently, the application doesn't require environment variables. If needed in the future, add them to the deployment.yaml:

```yaml
env:
- name: EXAMPLE_VAR
  value: "example-value"
```

### Secrets
For sensitive configuration, use Kubernetes secrets:

```bash
kubectl create secret generic grpc-retry-fun-secret \
  --from-literal=key=value \
  -n yet-another
```

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review logs: `kubectl logs -n yet-another -l app=grpc-retry-fun`
3. Check GitHub Actions workflow logs for deployment issues
