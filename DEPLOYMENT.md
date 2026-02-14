# Deployment Guide

This guide provides instructions for deploying the gRPC Greeter application to Azure Kubernetes Service (AKS).

## Prerequisites

1. **Azure CLI** - Install from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
2. **kubectl** - Install from https://kubernetes.io/docs/tasks/tools/
3. **Docker** - Install from https://docs.docker.com/get-docker/
4. **Azure Subscription** - Access to subscription ID: `d0ecd0d2-779b-4fd0-8f04-d46d07f05703`

## GitHub Actions Setup

### Required Secrets

Configure these secrets in your GitHub repository (Settings → Secrets and variables → Actions):

- `AZURE_CLIENT_ID`: Your Azure AD application client ID (placeholder: `123123`)
- `AZURE_TENANT_ID`: `72f988bf-86f1-41af-91ab-2d7cd011db47`
- `AZURE_SUBSCRIPTION_ID`: `d0ecd0d2-779b-4fd0-8f04-d46d07f05703`

**⚠️ IMPORTANT**: Replace placeholder values with actual credentials. Never commit real credentials to the repository.

### OIDC Configuration

The workflow uses OpenID Connect (OIDC) for secure authentication with Azure. Ensure your Azure AD application is configured with federated credentials for GitHub Actions.

Reference: https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure

### Automatic Deployment

The GitHub Actions workflow (`.github/workflows/deploy-to-aks.yml`) automatically:

1. Builds the Docker image
2. Pushes it to Azure Container Registry
3. Deploys to AKS cluster `thgamble_dt` in namespace `somens`

**Triggers:**
- Push to `main` branch with changes to `deploy/**`, `Dockerfile`, or `greeter_server/**`
- Manual trigger via `workflow_dispatch`

## Manual Deployment

### Step 1: Build Docker Image

```bash
# Build the image
docker build -t grpc-retry-fun:1.0 .

# Verify the build
docker images grpc-retry-fun:1.0

# Test locally (optional)
docker run -p 80:80 grpc-retry-fun:1.0
```

### Step 2: Push to Azure Container Registry

```bash
# Login to Azure
az login --tenant 72f988bf-86f1-41af-91ab-2d7cd011db47

# Set subscription
az account set --subscription d0ecd0d2-779b-4fd0-8f04-d46d07f05703

# Login to ACR (replace with your ACR name)
az acr login --name <your-acr-name>

# Tag and push the image
docker tag grpc-retry-fun:1.0 asdfasdf:1.0
docker push asdfasdf:1.0
```

### Step 3: Deploy to AKS

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group thgamble_dt_group \
  --name thgamble_dt

# Verify cluster connection
kubectl cluster-info

# Create namespace (if it doesn't exist)
kubectl create namespace somens

# Apply Kubernetes manifests
kubectl apply -f deploy/kubernetes/

# Verify deployment
kubectl get all -n somens
```

### Step 4: Verify Deployment

```bash
# Check pod status
kubectl get pods -n somens -l app=asdfa

# Check service
kubectl get svc -n somens -l app=asdfa

# View logs
kubectl logs -n somens -l app=asdfa --tail=50 -f

# Check deployment rollout status
kubectl rollout status deployment/asdfa-deployment -n somens
```

## Testing the Application

### From Within the Cluster

```bash
# Run a test client pod
kubectl run -n somens grpc-test --rm -it --restart=Never \
  --image=fullstorydev/grpcurl:latest -- \
  -plaintext asdfa-service:80 list

# Test the SayHello method
kubectl run -n somens grpc-test --rm -it --restart=Never \
  --image=fullstorydev/grpcurl:latest -- \
  -plaintext -d '{"name": "World"}' \
  asdfa-service:80 helloworld.Greeter/SayHello
```

### Port Forwarding (for local testing)

```bash
# Forward service port to local machine
kubectl port-forward -n somens svc/asdfa-service 8080:80

# In another terminal, test with grpcurl
grpcurl -plaintext -d '{"name": "World"}' \
  localhost:8080 helloworld.Greeter/SayHello
```

## Rollback

If you need to rollback a deployment:

```bash
# View rollout history
kubectl rollout history deployment/asdfa-deployment -n somens

# Rollback to previous version
kubectl rollout undo deployment/asdfa-deployment -n somens

# Rollback to specific revision
kubectl rollout undo deployment/asdfa-deployment -n somens --to-revision=2
```

## Scaling

```bash
# Scale up replicas
kubectl scale deployment/asdfa-deployment -n somens --replicas=3

# Verify scaling
kubectl get pods -n somens -l app=asdfa
```

## Monitoring

### View Logs

```bash
# Tail logs from all pods
kubectl logs -n somens -l app=asdfa -f --tail=100

# Logs from a specific pod
kubectl logs -n somens <pod-name> -f
```

### View Events

```bash
# Recent events in the namespace
kubectl get events -n somens --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl get events -n somens --watch
```

### Describe Resources

```bash
# Describe deployment
kubectl describe deployment asdfa-deployment -n somens

# Describe a pod
kubectl describe pod <pod-name> -n somens

# Describe service
kubectl describe svc asdfa-service -n somens
```

## Troubleshooting

### Pod CrashLoopBackOff

```bash
# Check pod logs
kubectl logs -n somens <pod-name> --previous

# Describe the pod for events
kubectl describe pod -n somens <pod-name>

# Check resource limits
kubectl top pod -n somens <pod-name>
```

### Image Pull Errors

```bash
# Verify image exists in ACR
az acr repository show --name <acr-name> --image asdfasdf:1.0

# Check if AKS has permission to pull from ACR
az aks check-acr --name thgamble_dt --resource-group thgamble_dt_group --acr <acr-name>.azurecr.io
```

### Service Not Accessible

```bash
# Check endpoints
kubectl get endpoints -n somens asdfa-service

# Verify pod labels match service selector
kubectl get pods -n somens --show-labels

# Check service configuration
kubectl describe svc -n somens asdfa-service
```

### Health Probes Failing

```bash
# Check if port 80 is listening in the container
kubectl exec -n somens <pod-name> -- netstat -tlnp

# Test TCP connectivity
kubectl exec -n somens <pod-name> -- nc -zv localhost 80
```

## Cleanup

To remove the deployment:

```bash
# Delete all resources
kubectl delete -f deploy/kubernetes/ -n somens

# Or delete the namespace (removes everything)
kubectl delete namespace somens
```

## Architecture

```
┌─────────────────────────────────────────┐
│         Azure Kubernetes Service        │
│              (thgamble_dt)              │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │      Namespace: somens            │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │  Deployment: asdfa          │ │ │
│  │  │  Replicas: 1                │ │ │
│  │  │                             │ │ │
│  │  │  ┌───────────────────────┐  │ │ │
│  │  │  │  Pod: asdfa-xxx       │  │ │ │
│  │  │  │  Image: asdfasdf:1.0  │  │ │ │
│  │  │  │  Port: 80 (gRPC)      │  │ │ │
│  │  │  │  CPU: 100m-500m       │  │ │ │
│  │  │  │  Memory: 128Mi-512Mi  │  │ │ │
│  │  │  └───────────────────────┘  │ │ │
│  │  └─────────────────────────────┘ │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │  Service: asdfa-service     │ │ │
│  │  │  Type: ClusterIP            │ │ │
│  │  │  Port: 80 → TargetPort: 80  │ │ │
│  │  └─────────────────────────────┘ │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
           ↑
           │ kubectl / GitHub Actions
           │
    ┌──────────────┐
    │  Developer   │
    └──────────────┘
```

## Security Considerations

- Container runs with minimal Alpine base image (23.5MB)
- All unnecessary capabilities dropped
- Privilege escalation disabled
- Uses OIDC for GitHub Actions authentication (no static credentials)
- Service is ClusterIP only (internal access)

**Security Context Settings**: The deployment uses `runAsNonRoot: false` and `readOnlyRootFilesystem: false` as specified in the requirements. For production environments, consider enabling these security features after verifying application compatibility:
- Set `runAsNonRoot: true` with a specific non-root user ID
- Set `readOnlyRootFilesystem: true` if the application doesn't require write access to the filesystem

## Resource Configuration

The deployment is configured with:

- **CPU Request**: 100m (0.1 cores)
- **CPU Limit**: 500m (0.5 cores)
- **Memory Request**: 128Mi
- **Memory Limit**: 512Mi
- **Pod Anti-Affinity**: Enabled for HA
- **Topology Spread**: Enabled for even distribution

## Support

For issues or questions:
1. Check pod logs: `kubectl logs -n somens -l app=asdfa`
2. Check events: `kubectl get events -n somens --sort-by='.lastTimestamp'`
3. Review the [deploy/README.md](deploy/README.md) for detailed information
