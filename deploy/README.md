# Deployment Configuration

This directory contains the Kubernetes manifests and deployment configuration for the `grpc-retry-fun` application on Azure Kubernetes Service (AKS).

## Structure

```
deploy/
├── kubernetes/
│   ├── deployment.yaml    # Kubernetes Deployment configuration
│   └── service.yaml       # Kubernetes Service configuration
└── README.md             # This file
```

## Configuration Details

### Application
- **Name:** grpc-retry-fun
- **Image:** grpc-retry-fun:1.0 (⚠️ **Note:** Update to full registry path before deploying, e.g., `yourregistry.azurecr.io/grpc-retry-fun:1.0`)
- **Port:** 80 (gRPC)
- **Namespace:** a-project

### Resources
- **Replicas:** 1
- **CPU Request:** 100m
- **CPU Limit:** 500m
- **Memory Request:** 128Mi
- **Memory Limit:** 512Mi

### Service
- **Type:** ClusterIP
- **Target Port:** 80

### High Availability Features
- **Pod Anti-Affinity:** Enabled (prefers scheduling on different nodes)
- **Topology Spread Constraints:** Enabled (distributes across zones and nodes)

### Health Checks
- **Liveness Probe:** TCP check on port 80
- **Readiness Probe:** TCP check on port 80
- **Startup Probe:** TCP check on port 80 (up to 60 seconds)

### Security
- **Allow Privilege Escalation:** false
- **Capabilities:** All dropped
- **Run As Non-Root:** false
- **Read-Only Root Filesystem:** false

## Deployment

### Prerequisites

⚠️ **IMPORTANT**: Before deploying, you must:

1. **Build and push the Docker image to a container registry:**
   ```bash
   # Build the image
   docker build -t grpc-retry-fun:1.0 .
   
   # Tag for your registry (example using Azure Container Registry)
   docker tag grpc-retry-fun:1.0 yourregistry.azurecr.io/grpc-retry-fun:1.0
   
   # Login to your registry
   az acr login --name yourregistry
   
   # Push the image
   docker push yourregistry.azurecr.io/grpc-retry-fun:1.0
   ```

2. **Update the image reference in `deploy/kubernetes/deployment.yaml`:**
   ```yaml
   image: yourregistry.azurecr.io/grpc-retry-fun:1.0
   ```

3. **Configure AKS to pull from your registry** (if using private registry):
   ```bash
   # Create a service principal or use managed identity
   az aks update -n dt -g thgamble --attach-acr yourregistry
   ```

### Automated Deployment (GitHub Actions)

The deployment is automated via GitHub Actions workflow. To deploy:

1. Go to the **Actions** tab in the GitHub repository
2. Select the **Deploy to AKS** workflow
3. Click **Run workflow**
4. Optionally override the default parameters:
   - **cluster-name:** dt (default)
   - **resource-group:** thgamble (default)
   - **namespace:** a-project (default)
   - **subscription-id:** d98169bc-2d4a-491b-98cb-b69cbf002eb0 (default)
5. Click **Run workflow** to start the deployment

### Manual Deployment

To deploy manually using `kubectl`:

```bash
# Set your Azure credentials
az login

# Set AKS context
az aks get-credentials --name dt --resource-group thgamble

# Create namespace if it doesn't exist
kubectl create namespace a-project --dry-run=client -o yaml | kubectl apply -f -

# Apply the Kubernetes manifests
kubectl apply -f deploy/kubernetes/ -n a-project

# Check deployment status
kubectl rollout status deployment/grpc-retry-fun -n a-project

# Verify pods are running
kubectl get pods -n a-project -l app=grpc-retry-fun

# Check service
kubectl get svc -n a-project -l app=grpc-retry-fun
```

### Validation

Validate manifests before applying:

```bash
# Dry-run validation
kubectl apply --dry-run=client -f deploy/kubernetes/

# Server-side validation
kubectl apply --dry-run=server -f deploy/kubernetes/ -n a-project
```

## Annotations

All deployments include the following annotations:
- `aks-desktop/deployed-by: pipeline` - Indicates deployment source
- `aks-desktop/pipeline-repo: gambtho/grpc-retry-fun` - Source repository
- `aks-desktop/pipeline-run-url` - Link to the GitHub Actions run (added during deployment)

## Monitoring

Check the application status:

```bash
# Get pods
kubectl get pods -n a-project -l app=grpc-retry-fun

# View logs
kubectl logs -n a-project -l app=grpc-retry-fun --tail=100 -f

# Describe deployment
kubectl describe deployment grpc-retry-fun -n a-project

# View events
kubectl get events -n a-project --field-selector involvedObject.name=grpc-retry-fun
```

## Troubleshooting

### Pod not starting

```bash
# Check pod status
kubectl get pods -n a-project -l app=grpc-retry-fun

# Describe pod for events
kubectl describe pod <pod-name> -n a-project

# Check logs
kubectl logs <pod-name> -n a-project
```

### Service not accessible

```bash
# Check service endpoints
kubectl get endpoints grpc-retry-fun -n a-project

# Verify service configuration
kubectl describe svc grpc-retry-fun -n a-project
```

## Scaling

To scale the deployment:

```bash
# Scale to 3 replicas
kubectl scale deployment grpc-retry-fun --replicas=3 -n a-project

# Or edit the deployment.yaml and apply
kubectl apply -f deploy/kubernetes/deployment.yaml -n a-project
```

## Rollback

To rollback to a previous version:

```bash
# View rollout history
kubectl rollout history deployment/grpc-retry-fun -n a-project

# Rollback to previous version
kubectl rollout undo deployment/grpc-retry-fun -n a-project

# Rollback to specific revision
kubectl rollout undo deployment/grpc-retry-fun --to-revision=<revision> -n a-project
```

## Azure Configuration

The deployment uses the following Azure resources:
- **Cluster:** dt
- **Resource Group:** thgamble
- **Subscription ID:** d98169bc-2d4a-491b-98cb-b69cbf002eb0
- **Tenant ID:** b06f66c5-f30b-4797-8dec-52cc6568e9aa

### Required Secrets

For GitHub Actions deployment, configure these secrets in your repository:
- `AZURE_CLIENT_ID` - Azure service principal client ID
- `AZURE_TENANT_ID` - Azure tenant ID (b06f66c5-f30b-4797-8dec-52cc6568e9aa)

## Application Information

This is a Go gRPC server application that:
- Listens on port 80 for gRPC connections
- Implements a simple Greeter service
- Built with Go 1.19
- Uses a minimal distroless container image (~11MB)
