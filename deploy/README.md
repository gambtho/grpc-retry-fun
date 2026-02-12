# Deployment Configuration for grpc-retry-fun

This directory contains all the necessary deployment configurations for the grpc-retry-fun gRPC application to run on Azure Kubernetes Service (AKS).

## Overview

The grpc-retry-fun application is a Go-based gRPC greeter server that demonstrates retry behavior in gRPC communications. This deployment is configured for the `thgamble_dt` AKS cluster in the `somens` namespace.

## Architecture

- **Application**: Go 1.19 gRPC greeter server
- **Port**: 50051 (gRPC)
- **Base Image**: Distroless (gcr.io/distroless/static-debian11:nonroot)
- **Image Tag**: 1.0
- **Image Size**: ~11MB

## Directory Structure

```
deploy/
├── kubernetes/
│   ├── namespace.yaml       # Namespace definition
│   ├── deployment.yaml      # Application deployment
│   ├── service.yaml         # ClusterIP service
│   └── hpa.yaml            # Horizontal Pod Autoscaler
└── README.md               # This file
```

## Kubernetes Resources

### Namespace
- **Name**: somens
- **Environment**: production

### Deployment
- **Name**: grpc-retry-fun
- **Replicas**: 2 (minimum)
- **Container**: greeter-server
- **Image**: grpc-retry-fun:1.0
- **Resources**:
  - Requests: 100m CPU, 64Mi Memory
  - Limits: 200m CPU, 128Mi Memory
- **Probes**:
  - Liveness: TCP check on port 50051
  - Readiness: TCP check on port 50051
- **Security**:
  - Non-root user (UID 65532)
  - Read-only root filesystem
  - No privilege escalation
  - All capabilities dropped

### Service
- **Name**: grpc-retry-fun
- **Type**: ClusterIP
- **Port**: 50051 (gRPC)

### Horizontal Pod Autoscaler (HPA)
- **Min Replicas**: 2
- **Max Replicas**: 10
- **Target CPU**: 70%
- **Target Memory**: 80%

## AKS Cluster Configuration

- **Cluster**: thgamble_dt
- **Resource Group**: thgamble_dt_group
- **Namespace**: somens
- **Tenant ID**: 72f988bf-86f1-41af-91ab-2d7cd011db47
- **Identity ID**: 1c65e916-5221-48f1-b437-178f0441ae61
- **Subscription ID**: d0ecd0d2-779b-4fd0-8f04-d46d07f05703

## Manual Deployment

### Prerequisites
- Azure CLI installed and authenticated
- kubectl configured
- Docker installed (for building images)
- Access to the AKS cluster

### Build the Docker Image

```bash
# From the repository root
docker build -t grpc-retry-fun:1.0 -f Dockerfile .
```

### Deploy to AKS

```bash
# Set context to the AKS cluster
az aks get-credentials --resource-group thgamble_dt_group --name thgamble_dt

# Apply all Kubernetes manifests
kubectl apply -f deploy/kubernetes/ -n somens

# Verify deployment
kubectl get deployments -n somens
kubectl get pods -n somens
kubectl get services -n somens
kubectl get hpa -n somens
```

### Validate Manifests (Dry Run)

```bash
kubectl apply --dry-run=client -f deploy/kubernetes/
```

## CI/CD Pipeline

The application includes a GitHub Actions workflow (`.github/workflows/deploy-to-aks.yml`) that automates:
1. Building the Docker image
2. Pushing to a container registry (if configured)
3. Deploying to the AKS cluster

The workflow uses OIDC authentication with Azure and is triggered on:
- Push to `main` branch (when `deploy/**` files change)
- Manual workflow dispatch

## Monitoring and Operations

### View Logs
```bash
kubectl logs -f deployment/grpc-retry-fun -n somens
```

### Scale Manually
```bash
kubectl scale deployment grpc-retry-fun --replicas=3 -n somens
```

### Check HPA Status
```bash
kubectl get hpa grpc-retry-fun-hpa -n somens
kubectl describe hpa grpc-retry-fun-hpa -n somens
```

### Port Forward for Local Testing
```bash
kubectl port-forward service/grpc-retry-fun 50051:50051 -n somens
```

## Troubleshooting

### Pod Not Starting
```bash
kubectl describe pod <pod-name> -n somens
kubectl logs <pod-name> -n somens
```

### Service Not Accessible
```bash
kubectl get endpoints grpc-retry-fun -n somens
kubectl describe service grpc-retry-fun -n somens
```

### HPA Not Scaling
```bash
kubectl describe hpa grpc-retry-fun-hpa -n somens
kubectl top pods -n somens
```

## Security Considerations

- Container runs as non-root user (UID 65532)
- Uses distroless base image for minimal attack surface
- Read-only root filesystem
- No privilege escalation allowed
- All Linux capabilities dropped
- Resource limits enforced

## Notes

- The application expects to run on port 50051 by default
- The deployment uses a ClusterIP service, so it's only accessible within the cluster
- For external access, consider adding an Ingress resource or changing the service type
- The HPA requires the metrics-server to be installed in the cluster
