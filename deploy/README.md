# AKS Deployment Guide

This document describes the AKS deployment infrastructure for the grpc-retry-fun application.

## Overview

The deployment consists of:
- **Dockerfile**: Multi-stage build for containerizing the Go gRPC server
- **Kubernetes Manifests**: Deployment and Service definitions
- **GitHub Actions Workflow**: Automated CI/CD pipeline for AKS deployment

## Prerequisites

Before deploying to AKS, ensure you have:

1. **Azure Resources**:
   - Azure Container Registry (ACR)
   - AKS cluster: `headlamp-thgamble` in resource group `thgamble`
   - Namespace `yet-another` (automatically created by the workflow)

2. **GitHub Secrets** (configured in repository settings):
   - `ACR_NAME`: Name of your Azure Container Registry
   - `AZURE_CLIENT_ID`: Azure AD application (service principal) client ID for OIDC authentication

3. **Azure OIDC Configuration**:
   - Tenant ID: `b06f66c5-f30b-4797-8dec-52cc6568e9aa`
   - Subscription ID: `d98169bc-2d4a-491b-98cb-b69cbf002eb0`
   - The service principal must have:
     - `AcrPush` role on the ACR
     - `Azure Kubernetes Service Cluster User Role` on the AKS cluster

## Architecture

### Container Image

The Dockerfile uses a multi-stage build:
1. **Builder stage**: Compiles the Go application using `golang:1.19-alpine`
2. **Runtime stage**: Uses `gcr.io/distroless/static-debian11:nonroot` for minimal attack surface

The application runs on port 80 (configurable via `-port` flag).

### Kubernetes Resources

#### Deployment (`deploy/kubernetes/deployment.yaml`)

- **Replicas**: 1 pod
- **Resources**:
  - CPU: 100m request, 500m limit
  - Memory: 128Mi request, 512Mi limit
- **Health Probes**: TCP socket checks on port 80
  - Liveness: 10s initial delay, 10s period
  - Readiness: 5s initial delay, 5s period
  - Startup: 0s initial delay, 5s period, 30 failures allowed (2.5 minutes total)
- **Security Context**:
  - `runAsNonRoot: false`
  - `readOnlyRootFilesystem: false`
  - `allowPrivilegeEscalation: false`
- **Affinity**: Pod anti-affinity to prefer spreading pods across nodes
- **Topology Spread**: Ensures even distribution across topology domains

#### Service (`deploy/kubernetes/service.yaml`)

- **Type**: ClusterIP (internal access only)
- **Port**: 80 (TCP)
- **Target Port**: 80

## Deployment Process

### Automated Deployment (via GitHub Actions)

The workflow is triggered on:
- Push to `main` branch
- Manual trigger via `workflow_dispatch`

**Deployment Steps**:
1. Checkout code
2. Authenticate to Azure using OIDC
3. Get ACR login server
4. Login to ACR
5. Build and push Docker image (tagged with commit SHA)
6. Set up kubeconfig for AKS
7. Create namespace if it doesn't exist
8. Deploy Kubernetes manifests
9. Wait for deployment rollout
10. Verify deployment

### Manual Deployment

To deploy manually:

```bash
# Set environment variables
export ACR_NAME="your-acr-name"
export IMAGE_TAG="v1.0.0"

# Build and push Docker image
docker build -t ${ACR_NAME}.azurecr.io/grpc-retry-fun:${IMAGE_TAG} .
docker push ${ACR_NAME}.azurecr.io/grpc-retry-fun:${IMAGE_TAG}

# Deploy to AKS
az aks get-credentials --resource-group thgamble --name headlamp-thgamble

# Create namespace
kubectl create namespace yet-another --dry-run=client -o yaml | kubectl apply -f -

# Apply manifests
envsubst < deploy/kubernetes/deployment.yaml | kubectl apply -f -
kubectl apply -f deploy/kubernetes/service.yaml
```

## Verification

After deployment, verify the resources:

```bash
# Check pod status
kubectl get pods -n yet-another -l app=grpc-retry-fun

# Check service
kubectl get svc -n yet-another -l app=grpc-retry-fun

# View logs
kubectl logs -n yet-another -l app=grpc-retry-fun --tail=100

# Check deployment status
kubectl rollout status deployment/grpc-retry-fun -n yet-another
```

## Configuration

### Updating Configuration

To modify the deployment configuration:

1. **Resource limits**: Edit `deploy/kubernetes/deployment.yaml`, section `resources`
2. **Health probes**: Edit probe settings in `deploy/kubernetes/deployment.yaml`
3. **Replicas**: Edit `spec.replicas` in `deploy/kubernetes/deployment.yaml`
4. **Service type**: Edit `spec.type` in `deploy/kubernetes/service.yaml`

### Environment Variables

The GitHub Actions workflow uses these environment variables:
- `ACR_NAME`: From GitHub secret
- `CLUSTER_NAME`: headlamp-thgamble
- `RESOURCE_GROUP`: thgamble
- `NAMESPACE`: yet-another
- `APP_NAME`: grpc-retry-fun

## Troubleshooting

### Common Issues

1. **Image pull errors**:
   - Verify ACR authentication
   - Check that the service principal has `AcrPull` role

2. **Pod startup failures**:
   - Check logs: `kubectl logs -n yet-another -l app=grpc-retry-fun`
   - Verify the startup probe gives enough time (currently 2.5 minutes)

3. **Deployment stuck**:
   - Check pod events: `kubectl describe pod -n yet-another -l app=grpc-retry-fun`
   - Verify resource quotas in the namespace

4. **Health probe failures**:
   - Ensure the application listens on port 80
   - Verify TCP connectivity within the cluster

## Security Considerations

- Uses distroless base image for minimal attack surface
- OIDC authentication instead of service principal keys
- Private ACR with RBAC
- Network policies can be added for additional pod-to-pod isolation
- Security context configured per requirements:
  - `runAsNonRoot: false` - allows running as root per configuration
  - `readOnlyRootFilesystem: false` - allows writable filesystem per configuration
  - `allowPrivilegeEscalation: false` - prevents privilege escalation
