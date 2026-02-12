# Kubernetes Deployment for gRPC Retry Fun

This directory contains Kubernetes manifests for deploying the gRPC Greeter Server application to Azure Kubernetes Service (AKS).

## Architecture

- **Application**: Go-based gRPC server running on port 50051
- **Container Image**: grpc-retry-fun:1.0 (8.58MB scratch-based image)
- **Container Registry**: Azure Container Registry (ACR) - auto-detected from resource group
- **Service Type**: ClusterIP (internal access only)
- **Namespace**: somens
- **Replicas**: 2 (for high availability)

## Files

- `namespace.yaml`: Creates the `somens` namespace
- `deployment.yaml`: Defines the application deployment with 2 replicas
- `service.yaml`: Exposes the gRPC server internally via ClusterIP

## Resource Limits

- **Requests**: 100m CPU, 64Mi memory
- **Limits**: 200m CPU, 128Mi memory

## Health Checks

- **Liveness Probe**: TCP check on port 50051 every 10 seconds
- **Readiness Probe**: TCP check on port 50051 every 5 seconds

## Manual Deployment

To deploy manually to AKS:

```bash
# Login to Azure
az login

# Set the AKS context
az aks get-credentials --resource-group thgamble_dt_group --name thgamble_dt

# Apply the manifests
kubectl apply -f deploy/kubernetes/namespace.yaml
kubectl apply -f deploy/kubernetes/deployment.yaml
kubectl apply -f deploy/kubernetes/service.yaml

# Verify the deployment
kubectl get pods -n somens
kubectl get svc -n somens
```

## Validation

Validate the manifests before applying:

```bash
kubectl apply --dry-run=client -f deploy/kubernetes/
```

## Accessing the Service

Since the service type is ClusterIP, it's only accessible from within the cluster:

```bash
# From another pod in the cluster
grpc-retry-fun-service.somens.svc.cluster.local:50051
```

## CI/CD Deployment

The application is automatically deployed via GitHub Actions on push to the main branch. See `.github/workflows/deploy-to-aks.yml` for details.

## AKS Configuration

- **Cluster**: thgamble_dt
- **Resource Group**: thgamble_dt_group
- **Subscription ID**: d0ecd0d2-779b-4fd0-8f04-d46d07f05703
- **Tenant ID**: 72f988bf-86f1-41af-91ab-2d7cd011db47
