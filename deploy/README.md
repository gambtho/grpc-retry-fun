# AKS Deployment Guide for grpc-retry-fun

This directory contains the deployment configuration for the gRPC retry fun application on Azure Kubernetes Service (AKS).

## Overview

The application is a gRPC server written in Go that demonstrates retry functionality. It runs on port 50051 and is deployed to AKS with production-ready configurations including security hardening, health checks, and high availability.

## Architecture

### Container Image
- **Base Image**: `gcr.io/distroless/static-debian11:nonroot`
- **Size**: ~11MB (minimal attack surface)
- **Security**: Non-root user (UID 65532), read-only filesystem, no shell
- **Build**: Multi-stage build with Go 1.21

### Kubernetes Resources

The deployment includes the following Kubernetes resources:

1. **Deployment** (`deployment.yaml`)
   - 2 replicas for high availability
   - Resource limits: CPU 500m, Memory 256Mi
   - Security hardening: non-root, read-only filesystem, dropped capabilities
   - Health checks: liveness, readiness, and startup probes
   - Rolling update strategy

2. **Service** (`service.yaml`)
   - Type: ClusterIP
   - Port: 50051 (gRPC)
   - Internal cluster access only

3. **ConfigMap** (`configmap.yaml`)
   - Application configuration
   - Port and environment variables

4. **PodDisruptionBudget** (`pdb.yaml`)
   - Ensures at least 1 pod is always available
   - Protects against voluntary disruptions

5. **NetworkPolicy** (`networkpolicy.yaml`)
   - Restricts ingress to namespace only
   - Allows egress for DNS resolution

## Deployment Configuration

### AKS Cluster Details
- **Cluster Name**: thgamble_dt
- **Resource Group**: thgamble_dt_group
- **Namespace**: somens
- **Tenant ID**: 72f988bf-86f1-41af-91ab-2d7cd011db47
- **Subscription ID**: d0ecd0d2-779b-4fd0-8f04-d46d07f05703

### Authentication
The deployment uses Azure OIDC Workload Identity for authentication. The following secrets must be configured in GitHub:

- `AZURE_CLIENT_ID`: Azure AD Application (Service Principal) Client ID
- `AZURE_TENANT_ID`: Azure AD Tenant ID (72f988bf-86f1-41af-91ab-2d7cd011db47)
- `AZURE_SUBSCRIPTION_ID`: Azure Subscription ID (d0ecd0d2-779b-4fd0-8f04-d46d07f05703)

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/deploy-to-aks.yml`) automates the build and deployment process:

### Workflow Triggers
- Push to `main` branch with changes to:
  - `deploy/**`
  - `greeter_server/**`
  - `helloworld/**`
  - `Dockerfile`
  - `go.mod`, `go.sum`
  - Workflow file itself
- Manual trigger via `workflow_dispatch`

### Workflow Steps

#### Build and Push Job
1. Checkout code
2. Set up Docker Buildx
3. Log in to GitHub Container Registry (GHCR)
4. Extract Docker metadata (tags and labels)
5. Build and push multi-platform Docker image (linux/amd64)
   - Tagged with version 1.0
   - Cached for faster builds

#### Deploy to AKS Job
1. Checkout code
2. Authenticate to Azure using OIDC
3. Set up kubectl
4. Get AKS cluster credentials
5. Create namespace if it doesn't exist
6. Update deployment manifests with new image reference
7. Apply Kubernetes manifests
8. Wait for rollout to complete
9. Verify deployment status
10. Display logs on failure

## Manual Deployment

### Prerequisites
- Azure CLI installed and configured
- kubectl installed
- Access to AKS cluster
- Docker for building images locally

### Build Docker Image
```bash
docker build -t grpc-retry-fun:1.0 .
```

### Push to Container Registry
```bash
# Tag for your registry
docker tag grpc-retry-fun:1.0 ghcr.io/<your-org>/grpc-retry-fun:1.0

# Push to registry
docker push ghcr.io/<your-org>/grpc-retry-fun:1.0
```

### Deploy to AKS
```bash
# Login to Azure
az login

# Get AKS credentials
az aks get-credentials --resource-group thgamble_dt_group --name thgamble_dt

# Create namespace
kubectl create namespace somens

# Update image reference in deployment.yaml if needed
# Then apply manifests
kubectl apply -f deploy/kubernetes/ -n somens

# Check deployment status
kubectl rollout status deployment/grpc-retry-fun -n somens

# Verify pods are running
kubectl get pods -n somens -l app=grpc-retry-fun

# Check service
kubectl get svc -n somens grpc-retry-fun
```

## Monitoring and Troubleshooting

### Check Pod Status
```bash
kubectl get pods -n somens -l app=grpc-retry-fun
```

### View Pod Logs
```bash
kubectl logs -n somens -l app=grpc-retry-fun --tail=100
```

### Describe Deployment
```bash
kubectl describe deployment grpc-retry-fun -n somens
```

### Check Events
```bash
kubectl get events -n somens --sort-by='.lastTimestamp'
```

### Port Forward for Local Testing
```bash
kubectl port-forward -n somens svc/grpc-retry-fun 50051:50051
```

### Scale Deployment
```bash
kubectl scale deployment grpc-retry-fun -n somens --replicas=3
```

## Security Considerations

1. **Non-root User**: Container runs as UID 65532 (distroless nonroot user)
2. **Read-only Filesystem**: Root filesystem is read-only with tmpfs for /tmp
3. **Dropped Capabilities**: All Linux capabilities are dropped
4. **No Privilege Escalation**: `allowPrivilegeEscalation: false`
5. **Distroless Base**: Minimal attack surface, no shell or package managers
6. **NetworkPolicy**: Restricts network access to namespace only
7. **PodSecurityContext**: Enforces security policies at pod level
8. **Resource Limits**: Prevents resource exhaustion attacks

## Performance Tuning

### Resource Adjustments
Edit `deploy/kubernetes/deployment.yaml` to adjust resources:

```yaml
resources:
  requests:
    cpu: 100m
    memory: 64Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

### Replica Count
Adjust replicas based on load:

```yaml
spec:
  replicas: 2  # Increase for higher availability
```

### Health Check Timing
Adjust probe timings for your application's startup time:

```yaml
startupProbe:
  initialDelaySeconds: 0
  periodSeconds: 5
  failureThreshold: 12  # 60 seconds total
```

## Updates and Rollbacks

### Update Image
```bash
kubectl set image deployment/grpc-retry-fun grpc-server=ghcr.io/<your-org>/grpc-retry-fun:1.1 -n somens
```

### Rollback to Previous Version
```bash
kubectl rollout undo deployment/grpc-retry-fun -n somens
```

### Check Rollout History
```bash
kubectl rollout history deployment/grpc-retry-fun -n somens
```

## Support and Maintenance

For issues or questions:
1. Check pod logs and events
2. Verify image is accessible in registry
3. Ensure Azure credentials are valid
4. Check AKS cluster health and node status
5. Review network policies and security groups

## Best Practices Applied

✅ Multi-stage Docker build for minimal image size  
✅ Distroless base image for security  
✅ Non-root user with dropped capabilities  
✅ Read-only root filesystem  
✅ Comprehensive health checks (liveness, readiness, startup)  
✅ Resource limits to prevent resource exhaustion  
✅ Rolling updates with zero downtime  
✅ PodDisruptionBudget for high availability  
✅ NetworkPolicy for network segmentation  
✅ OIDC authentication for secure Azure access  
✅ Infrastructure as Code with version control  
✅ Automated CI/CD pipeline  
✅ Proper monitoring and logging  

## License

This deployment configuration follows the same license as the application (Apache License 2.0).
