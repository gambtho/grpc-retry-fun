# Deployment Guide for grpc-retry-fun

This directory contains deployment manifests and instructions for deploying the grpc-retry-fun application to Azure Kubernetes Service (AKS).

## Overview

The grpc-retry-fun is a Go-based gRPC server application that demonstrates retry mechanisms. It's packaged as a minimal Docker container (~20MB) using a multi-stage build with a distroless runtime image for enhanced security.

## Architecture

- **Application**: Go 1.19 gRPC server
- **Port**: 50051 (gRPC)
- **Base Image**: gcr.io/distroless/static-debian11:nonroot
- **Service Type**: ClusterIP
- **Target Cluster**: headlamp-thgamble (AKS)
- **Namespace**: yet-another

## Kubernetes Resources

The deployment includes the following Kubernetes resources:

### 1. Deployment (`deployment.yaml`)
- **Replicas**: 2 (for high availability)
- **Security**: 
  - Runs as non-root user (UID 65532)
  - Read-only root filesystem
  - No privilege escalation
  - All capabilities dropped
  - Seccomp profile enabled
- **Resource Limits**:
  - CPU: 100m (request) / 200m (limit)
  - Memory: 64Mi (request) / 128Mi (limit)
- **Health Checks**:
  - Liveness probe: TCP socket on port 50051
  - Readiness probe: TCP socket on port 50051

### 2. Service (`service.yaml`)
- **Type**: ClusterIP (internal only)
- **Port**: 50051
- **Protocol**: TCP

### 3. HorizontalPodAutoscaler (`hpa.yaml`)
- **Min Replicas**: 2
- **Max Replicas**: 5
- **Metrics**:
  - CPU utilization target: 70%
  - Memory utilization target: 80%

### 4. PodDisruptionBudget (`pdb.yaml`)
- **Min Available**: 1 pod during voluntary disruptions

## Prerequisites

1. Azure CLI installed and configured
2. kubectl installed and configured
3. Access to the AKS cluster (headlamp-thgamble)
4. Docker image built and tagged as `grpc-retry-fun:1.0`

## Manual Deployment

### Build and Tag the Image

```bash
# Build the Docker image
docker build -t grpc-retry-fun:1.0 .

# Tag for your container registry (replace with your ACR name)
docker tag grpc-retry-fun:1.0 <your-acr>.azurecr.io/grpc-retry-fun:1.0

# Push to ACR
docker push <your-acr>.azurecr.io/grpc-retry-fun:1.0
```

### Update Deployment Manifests

Update the image reference in `kubernetes/deployment.yaml`:

```yaml
image: <your-acr>.azurecr.io/grpc-retry-fun:1.0
```

### Deploy to AKS

```bash
# Connect to AKS cluster
az aks get-credentials --resource-group thgamble --name headlamp-thgamble

# Create or verify namespace
kubectl create namespace yet-another --dry-run=client -o yaml | kubectl apply -f -

# Apply manifests
kubectl apply -f deploy/kubernetes/ -n yet-another

# Verify deployment
kubectl get all -n yet-another -l app=grpc-retry-fun
```

## Automated Deployment (GitHub Actions)

The repository includes a GitHub Actions workflow (`.github/workflows/deploy-to-aks.yml`) that automates the deployment process.

### Setup

1. Configure the following secrets in your GitHub repository:
   - `AZURE_CLIENT_ID`: Your Azure service principal client ID
   - `AZURE_TENANT_ID`: Your Azure tenant ID (b06f66c5-f30b-4797-8dec-52cc6568e9aa)

2. The workflow uses OIDC authentication for secure, keyless authentication to Azure.

### Trigger Deployment

The workflow is triggered manually via `workflow_dispatch`:

```bash
# Using GitHub CLI
gh workflow run deploy-to-aks.yml

# Or through the GitHub UI: Actions > Deploy to AKS > Run workflow
```

You can customize deployment parameters:
- `cluster-name` (default: headlamp-thgamble)
- `resource-group` (default: thgamble)
- `namespace` (default: yet-another)
- `subscription-id` (default: d98169bc-2d4a-491b-98cb-b69cbf002eb0)

## Verification

After deployment, verify the application:

```bash
# Check deployment status
kubectl rollout status deployment/grpc-retry-fun -n yet-another

# View pods
kubectl get pods -n yet-another -l app=grpc-retry-fun

# Check service
kubectl get svc grpc-retry-fun -n yet-another

# View logs
kubectl logs -n yet-another -l app=grpc-retry-fun --tail=100

# Port-forward for local testing
kubectl port-forward -n yet-another svc/grpc-retry-fun 50051:50051
```

## Testing

Once port-forwarded, you can test the gRPC server:

```bash
# In another terminal
cd greeter_client
go run main.go -addr=localhost:50051 -name=kubernetes
```

## Scaling

The application will automatically scale based on CPU and memory usage (via HPA). Manual scaling is also supported:

```bash
# Scale manually
kubectl scale deployment grpc-retry-fun -n yet-another --replicas=3

# View HPA status
kubectl get hpa grpc-retry-fun -n yet-another
```

## Security Features

This deployment follows security best practices:

1. **Container Security**:
   - Minimal distroless base image (no shell, package manager)
   - Non-root user (UID 65532)
   - Read-only root filesystem
   - No privilege escalation
   - All Linux capabilities dropped

2. **Pod Security**:
   - Seccomp profile enabled
   - Security context enforced at pod and container level

3. **Authentication**:
   - OIDC-based authentication (no stored credentials)

4. **Network**:
   - ClusterIP service (internal only)
   - No external exposure by default

## Troubleshooting

### Pods not starting

```bash
kubectl describe pod -n yet-another -l app=grpc-retry-fun
kubectl logs -n yet-another -l app=grpc-retry-fun
```

### Image pull errors

Ensure the image is pushed to your container registry and the deployment YAML references the correct image.

### Connection issues

Verify the service and pods are running:

```bash
kubectl get svc,pods -n yet-another -l app=grpc-retry-fun
```

## Cleanup

To remove the deployment:

```bash
kubectl delete -f deploy/kubernetes/ -n yet-another
```

## Support

For issues or questions, please open an issue in the repository.
