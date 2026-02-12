# Deployment Guide for grpc-retry-fun

This directory contains the deployment configuration for the gRPC Retry Fun application to Azure Kubernetes Service (AKS).

## Overview

The application is a Go-based gRPC server (greeter_server) that implements a simple "Hello World" service with gRPC retry capabilities.

## Architecture

- **Application**: Go gRPC server running on port 50051
- **Container**: Multi-stage Docker build using golang:1.19-alpine and scratch base (8.79MB)
- **Platform**: Azure Kubernetes Service (AKS)
- **Cluster**: thgamble_dt
- **Resource Group**: thgamble_dt_group
- **Namespace**: somens

## Directory Structure

```
deploy/
├── kubernetes/
│   ├── namespace.yaml     # Namespace definition
│   ├── deployment.yaml    # Deployment with 2 replicas
│   └── service.yaml       # ClusterIP service on port 50051
└── README.md             # This file
```

## Kubernetes Resources

### Namespace
- **Name**: somens
- **Purpose**: Isolates the application resources

### Deployment
- **Name**: grpc-retry-fun
- **Replicas**: 2
- **Container Image**: grpc-retry-fun:1.0
- **Port**: 50051 (gRPC)
- **Resources**:
  - Requests: 100m CPU, 64Mi memory
  - Limits: 200m CPU, 128Mi memory
- **Health Checks**:
  - Liveness probe: TCP socket on port 50051
  - Readiness probe: TCP socket on port 50051

### Service
- **Name**: grpc-retry-fun
- **Type**: ClusterIP
- **Port**: 50051
- **Protocol**: TCP

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/deploy-to-aks.yml`) automates the deployment:

1. **Build**: Creates Docker image with tag 1.0
2. **Login**: Authenticates to Azure using OIDC
3. **Push**: Pushes image to Azure Container Registry
4. **Deploy**: Applies Kubernetes manifests to AKS
5. **Verify**: Checks deployment rollout status

### Triggers
- Push to `main` branch with changes to:
  - `deploy/**`
  - `greeter_server/**`
  - `helloworld/**`
  - `go.mod`, `go.sum`
  - `Dockerfile`
  - `.github/workflows/deploy-to-aks.yml`
- Manual trigger via `workflow_dispatch`

### Required Secrets

The following secrets must be configured in GitHub repository settings:

- `AZURE_CLIENT_ID`: Azure AD application client ID
- `AZURE_TENANT_ID`: Azure AD tenant ID (configured in workflow)
- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID (configured in workflow)

## Manual Deployment

### Prerequisites
- Azure CLI installed and logged in
- kubectl configured with AKS credentials
- Docker installed for local image builds

### Steps

1. **Set AKS Context**:
   ```bash
   az aks get-credentials --resource-group thgamble_dt_group --name thgamble_dt
   ```

2. **Build Docker Image**:
   ```bash
   docker build -t grpc-retry-fun:1.0 .
   ```

3. **Push to ACR** (if using Azure Container Registry):
   ```bash
   ACR_NAME=$(az acr list --resource-group thgamble_dt_group --query "[0].name" -o tsv)
   az acr login --name $ACR_NAME
   docker tag grpc-retry-fun:1.0 ${ACR_NAME}.azurecr.io/grpc-retry-fun:1.0
   docker push ${ACR_NAME}.azurecr.io/grpc-retry-fun:1.0
   ```

4. **Update deployment.yaml** with ACR image path:
   ```bash
   sed -i "s|image: grpc-retry-fun:1.0|image: ${ACR_NAME}.azurecr.io/grpc-retry-fun:1.0|g" deploy/kubernetes/deployment.yaml
   ```

5. **Deploy to AKS**:
   ```bash
   kubectl apply -f deploy/kubernetes/ -n somens
   ```

6. **Verify Deployment**:
   ```bash
   kubectl get pods -n somens -l app=grpc-retry-fun
   kubectl get svc -n somens grpc-retry-fun
   kubectl logs -n somens -l app=grpc-retry-fun
   ```

## Testing the Service

Since the service is ClusterIP type, it's only accessible within the cluster. To test:

### Port Forward
```bash
kubectl port-forward -n somens svc/grpc-retry-fun 50051:50051
```

### Test with grpcurl
```bash
grpcurl -plaintext localhost:50051 helloworld.Greeter/SayHello -d '{"name": "World"}'
```

### Test with the Client
From within the cluster or after port-forwarding:
```bash
go run greeter_client/main.go --addr=localhost:50051
```

## Monitoring

Check deployment status:
```bash
kubectl get all -n somens -l app=grpc-retry-fun
kubectl describe deployment grpc-retry-fun -n somens
kubectl logs -n somens -l app=grpc-retry-fun --tail=50 -f
```

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod -n somens -l app=grpc-retry-fun
kubectl logs -n somens -l app=grpc-retry-fun
```

### Image pull errors
- Verify ACR access and credentials
- Check that the image exists in ACR:
  ```bash
  az acr repository show-tags --name $ACR_NAME --repository grpc-retry-fun
  ```

### Service not accessible
- Verify service endpoints:
  ```bash
  kubectl get endpoints -n somens grpc-retry-fun
  ```
- Check pod readiness:
  ```bash
  kubectl get pods -n somens -l app=grpc-retry-fun
  ```

## Cleanup

To remove the deployment:
```bash
kubectl delete -f deploy/kubernetes/ -n somens
```

To delete the namespace (removes all resources):
```bash
kubectl delete namespace somens
```

## Configuration

### AKS Cluster Details
- **Tenant ID**: 72f988bf-86f1-41af-91ab-2d7cd011db47
- **Subscription ID**: d0ecd0d2-779b-4fd0-8f04-d46d07f05703
- **Identity ID**: 1c65e916-5221-48f1-b437-178f0441ae61
- **Cluster Name**: thgamble_dt
- **Resource Group**: thgamble_dt_group
- **Namespace**: somens

## Security Considerations

- The container runs from a minimal scratch image (8.79MB)
- All dependencies are resolved at build time
- Container exposes only port 50051
- Service uses ClusterIP (internal only)
- Health checks ensure container responsiveness

## Updates and Rollbacks

### Update deployment
```bash
kubectl set image deployment/grpc-retry-fun grpc-server=grpc-retry-fun:1.1 -n somens
```

### Rollback deployment
```bash
kubectl rollout undo deployment/grpc-retry-fun -n somens
```

### Check rollout history
```bash
kubectl rollout history deployment/grpc-retry-fun -n somens
```
