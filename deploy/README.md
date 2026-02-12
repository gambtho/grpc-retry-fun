# Deployment Guide for grpc-retry-fun

This directory contains the deployment configuration for the gRPC Retry Fun application on Azure Kubernetes Service (AKS).

## Overview

The application is a Go-based gRPC server that demonstrates retry behavior in gRPC connections. It listens on port 50051 and implements a simple Greeter service.

## Architecture

- **Container Image**: Multi-stage Docker build using Go 1.19 and distroless runtime
- **Image Size**: ~10MB
- **Service Type**: ClusterIP (internal access only)
- **Replicas**: 2 (for high availability)
- **Resources**: Minimal footprint (64Mi-128Mi RAM, 100m-250m CPU)

## Deployment Configuration

### Azure Resources
- **Cluster**: thgamble_dt
- **Resource Group**: thgamble_dt_group
- **Namespace**: somens
- **Subscription ID**: d0ecd0d2-779b-4fd0-8f04-d46d07f05703
- **Tenant ID**: 72f988bf-86f1-41af-91ab-2d7cd011db47

### Kubernetes Resources
- **Deployment**: grpc-retry-fun (2 replicas)
- **Service**: grpc-retry-fun (ClusterIP on port 50051)
- **Namespace**: somens

## Files

```
deploy/
├── kubernetes/
│   ├── namespace.yaml      # Namespace definition
│   ├── deployment.yaml     # Deployment configuration
│   └── service.yaml        # Service definition
└── README.md              # This file
```

## Manual Deployment

### Prerequisites
1. Azure CLI installed and configured
2. kubectl installed
3. Access to the AKS cluster
4. Docker installed (for building images)

### Steps

1. **Login to Azure**:
   ```bash
   az login
   az account set --subscription d0ecd0d2-779b-4fd0-8f04-d46d07f05703
   ```

2. **Get AKS credentials**:
   ```bash
   az aks get-credentials --resource-group thgamble_dt_group --name thgamble_dt
   ```

3. **Build Docker image**:
   ```bash
   docker build -t grpc-retry-fun:1.0 .
   ```

4. **Push to Azure Container Registry**:
   ```bash
   # Tag for ACR
   docker tag grpc-retry-fun:1.0 <your-acr>.azurecr.io/grpc-retry-fun:1.0
   
   # Login to ACR
   az acr login --name <your-acr-name>
   
   # Push to ACR
   docker push <your-acr>.azurecr.io/grpc-retry-fun:1.0
   ```

5. **Update deployment manifest**:
   ```bash
   # Update the image reference in deployment.yaml
   sed -i 's|image: grpc-retry-fun:1.0|image: <your-acr>.azurecr.io/grpc-retry-fun:1.0|g' deploy/kubernetes/deployment.yaml
   ```

6. **Deploy to AKS**:
   ```bash
   kubectl apply -f deploy/kubernetes/ -n somens
   ```

7. **Verify deployment**:
   ```bash
   kubectl get pods -n somens -l app=grpc-retry-fun
   kubectl get service -n somens grpc-retry-fun
   ```

## Automated Deployment (CI/CD)

The GitHub Actions workflow at `.github/workflows/deploy-to-aks.yml` automates the deployment process.

### Setup Requirements

Configure the following GitHub secrets:
- `AZURE_CLIENT_ID`: 1c65e916-5221-48f1-b437-178f0441ae61
- `AZURE_TENANT_ID`: 72f988bf-86f1-41af-91ab-2d7cd011db47
- `AZURE_SUBSCRIPTION_ID`: d0ecd0d2-779b-4fd0-8f04-d46d07f05703
- `ACR_LOGIN_SERVER`: Your Azure Container Registry login server (e.g., `myacr.azurecr.io`)

**Note**: The workflow requires access to an Azure Container Registry (ACR). The image is pushed to ACR and then referenced in the deployment.

### Triggers

The workflow triggers on:
- Push to `main` branch (paths: `deploy/**`, `greeter_server/**`, `helloworld/**`, `Dockerfile`, workflow file)
- Manual dispatch via GitHub UI

### Workflow Steps

1. Checkout code
2. Build Docker image (tag: 1.0)
3. Login to Azure via OIDC
4. Login to Azure Container Registry (ACR)
5. Push image to ACR
6. Set AKS context
7. Create namespace (if needed)
8. Update deployment manifests with ACR image reference
9. Deploy Kubernetes manifests
10. Verify deployment status
11. Display deployment information

## Validation

### Validate Manifests Locally
```bash
kubectl apply --dry-run=client -f deploy/kubernetes/
```

### Check Deployment Status
```bash
kubectl rollout status deployment/grpc-retry-fun -n somens
```

### View Logs
```bash
kubectl logs -n somens -l app=grpc-retry-fun --tail=50 -f
```

### Test gRPC Service
From within the cluster:
```bash
# Port-forward to local machine
kubectl port-forward -n somens service/grpc-retry-fun 50051:50051

# Use grpc_cli or your client
grpc_cli call localhost:50051 SayHello "name: 'World'"
```

## Security Features

- **Non-root user**: Runs as UID 65532 (nonroot)
- **Read-only root filesystem**: Enhanced security
- **Dropped capabilities**: ALL capabilities dropped
- **Resource limits**: Prevents resource exhaustion
- **Security probes**: TCP-based liveness and readiness checks

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod -n somens -l app=grpc-retry-fun
kubectl logs -n somens -l app=grpc-retry-fun
```

### Service not accessible
```bash
kubectl get endpoints -n somens grpc-retry-fun
kubectl get service -n somens grpc-retry-fun
```

### Image pull issues
Ensure the image is available in the node's local Docker daemon or push to ACR:
```bash
# Tag for ACR
docker tag grpc-retry-fun:1.0 <your-acr>.azurecr.io/grpc-retry-fun:1.0

# Login to ACR
az acr login --name <your-acr-name>

# Push to ACR
docker push <your-acr>.azurecr.io/grpc-retry-fun:1.0

# Update deployment.yaml with ACR image reference
sed -i 's|image: grpc-retry-fun:1.0|image: <your-acr>.azurecr.io/grpc-retry-fun:1.0|g' deploy/kubernetes/deployment.yaml
```

## Local Development

For local testing with kind or minikube, use the alternative deployment:

```bash
# Build image locally
docker build -t grpc-retry-fun:1.0 .

# For kind: Load image into kind cluster
kind load docker-image grpc-retry-fun:1.0

# For minikube: Use minikube's Docker daemon
eval $(minikube docker-env)
docker build -t grpc-retry-fun:1.0 .

# Deploy using local configuration
kubectl apply -f deploy/kubernetes/namespace.yaml
kubectl apply -f deploy/kubernetes/deployment-local.yaml -n somens

# Access the service
kubectl port-forward -n somens service/grpc-retry-fun-local 50051:50051
# Or for minikube NodePort:
minikube service grpc-retry-fun-local -n somens
```

## Production Considerations

For production deployments, consider:

1. **Container Registry**: Push images to Azure Container Registry (ACR) instead of using local images
2. **Ingress**: Add Ingress controller for external access (if needed)
3. **TLS/mTLS**: Implement TLS for secure gRPC communication
4. **Monitoring**: Add Prometheus metrics and Grafana dashboards
5. **Logging**: Integrate with Azure Monitor or ELK stack
6. **Autoscaling**: Configure HPA (Horizontal Pod Autoscaler) based on CPU/memory
7. **Network Policies**: Restrict pod-to-pod communication
8. **Secrets Management**: Use Azure Key Vault for sensitive data
9. **Resource Quotas**: Set namespace resource quotas
10. **Backup**: Regular etcd backups and disaster recovery plan

## Support

For issues or questions:
- Check application logs: `kubectl logs -n somens -l app=grpc-retry-fun`
- Review events: `kubectl get events -n somens --sort-by='.lastTimestamp'`
- Inspect resources: `kubectl get all -n somens`
