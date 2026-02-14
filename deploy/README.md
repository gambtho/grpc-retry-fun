# Deployment Guide for grpc-retry-fun

This directory contains Kubernetes manifests and deployment configuration for the gRPC Greeter Server application running on Azure Kubernetes Service (AKS).

## Overview

The gRPC server is containerized using a multi-stage Docker build with a distroless base image for security and minimal size.

### Image Details
- **Base Image:** `gcr.io/distroless/static-debian11:nonroot`
- **Image Size:** ~20MB
- **User:** nonroot (UID 65532)
- **Port:** 50051 (gRPC)

## Directory Structure

```
deploy/
├── kubernetes/
│   ├── deployment.yaml    # Kubernetes Deployment manifest
│   ├── service.yaml       # Kubernetes Service (ClusterIP)
│   ├── configmap.yaml     # Configuration parameters
│   ├── hpa.yaml          # Horizontal Pod Autoscaler
│   └── pdb.yaml          # Pod Disruption Budget
└── README.md             # This file
```

## Prerequisites

1. **Azure CLI** installed and configured
2. **kubectl** installed
3. **Docker** for local testing
4. **Access to AKS cluster:**
   - Cluster: `thgamble_dt`
   - Resource Group: `thgamble_dt_group`
   - Namespace: `somens`
5. **Azure Container Registry (ACR):**
   - Required for storing Docker images
   - Must be accessible from AKS cluster
   - Can be attached to AKS or configured with pull secrets

## Local Testing

### Build and Test Docker Image

```bash
# Build the image
docker build -t grpc-retry-fun:1.0 .

# Run locally
docker run -p 50051:50051 grpc-retry-fun:1.0

# Test with the client (from another terminal)
cd greeter_client
go run main.go -name=World
```

## Kubernetes Deployment

### Manual Deployment

1. **Set up kubectl context:**
   ```bash
   az aks get-credentials --resource-group thgamble_dt_group --name thgamble_dt
   ```

2. **Build and push image to ACR:**
   ```bash
   # Login to ACR
   az acr login --name <your-acr-name>
   
   # Build and tag image
   docker build -t <your-acr-name>.azurecr.io/grpc-retry-fun:1.0 .
   
   # Push to ACR
   docker push <your-acr-name>.azurecr.io/grpc-retry-fun:1.0
   ```

3. **Update deployment manifest:**
   ```bash
   # Update the image reference in deployment.yaml
   sed -i "s|image: grpc-retry-fun:1.0|image: <your-acr-name>.azurecr.io/grpc-retry-fun:1.0|g" deploy/kubernetes/deployment.yaml
   ```

4. **Create namespace (if needed):**
   ```bash
   kubectl create namespace somens
   ```

5. **Validate manifests:**
   ```bash
   kubectl apply --dry-run=client -f deploy/kubernetes/
   ```

6. **Deploy to AKS:**
   ```bash
   kubectl apply -f deploy/kubernetes/ -n somens
   ```

7. **Verify deployment:**
   ```bash
   # Check pods
   kubectl get pods -n somens -l app=grpc-retry-fun
   
   # Check service
   kubectl get svc -n somens -l app=grpc-retry-fun
   
   # Check logs
   kubectl logs -n somens -l app=grpc-retry-fun --tail=50
   ```

### Automated Deployment (GitHub Actions)

The repository includes a GitHub Actions workflow (`.github/workflows/deploy-to-aks.yml`) that automatically deploys changes to AKS.

#### Setup GitHub Secrets

Configure the following secrets in your GitHub repository:

- `AZURE_CLIENT_ID`: Azure Service Principal Client ID
- `AZURE_TENANT_ID`: `72f988bf-86f1-41af-91ab-2d7cd011db47`
- `AZURE_SUBSCRIPTION_ID`: `d0ecd0d2-779b-4fd0-8f04-d46d07f05703`
- `ACR_NAME`: Azure Container Registry name (without .azurecr.io suffix)

**Note:** Ensure your AKS cluster has permission to pull images from the ACR. You can attach ACR to AKS:
```bash
az aks update -n thgamble_dt -g thgamble_dt_group --attach-acr <your-acr-name>
```

#### Trigger Deployment

The workflow triggers on:
- Push to `main` branch (when `deploy/**` or `Dockerfile` changes)
- Manual trigger via `workflow_dispatch`

## Configuration

### Deployment Specifications

- **Replicas:** 2 (for high availability)
- **Rolling Update Strategy:**
  - maxUnavailable: 0
  - maxSurge: 1
- **Resource Limits:**
  - CPU: 100m (request) / 500m (limit)
  - Memory: 128Mi (request) / 256Mi (limit)
- **Horizontal Pod Autoscaler (HPA):**
  - Min replicas: 2
  - Max replicas: 10
  - CPU target: 70%
  - Memory target: 80%
- **Pod Disruption Budget (PDB):**
  - Min available: 1 pod

### Security Features

- **Non-root user:** UID 65532
- **Read-only root filesystem**
- **No privilege escalation**
- **All capabilities dropped**
- **Seccomp profile:** RuntimeDefault

### Health Checks

- **Liveness Probe:** gRPC health check on port 50051
  - Initial delay: 10s
  - Period: 10s
  - Timeout: 5s
  - Failure threshold: 3

- **Readiness Probe:** gRPC health check on port 50051
  - Initial delay: 5s
  - Period: 5s
  - Timeout: 3s
  - Failure threshold: 3

- **Startup Probe:** gRPC health check on port 50051
  - Initial delay: 0s
  - Period: 5s
  - Timeout: 3s
  - Failure threshold: 12

## Service Configuration

- **Type:** ClusterIP
- **Port:** 50051
- **Target Port:** 50051
- **Protocol:** TCP

The service is only accessible within the cluster. To expose externally, consider:
1. Using an Ingress controller with gRPC support
2. Changing service type to LoadBalancer
3. Using Azure Application Gateway

## Troubleshooting

### Check Pod Status
```bash
kubectl describe pod -n somens -l app=grpc-retry-fun
kubectl logs -n somens -l app=grpc-retry-fun --tail=100
```

### Check Service Connectivity
```bash
# From within the cluster
kubectl run test-pod --rm -it --image=alpine --namespace=somens -- sh
# Inside the pod:
nc -zv grpc-retry-fun-service 50051
```

### Common Issues

1. **ImagePullBackOff:**
   - Ensure the image is built and available
   - Check image pull policy and registry access

2. **CrashLoopBackOff:**
   - Check logs: `kubectl logs -n somens <pod-name>`
   - Verify port configuration
   - Check resource limits

3. **Service not responding:**
   - Verify readiness probe is passing
   - Check network policies
   - Ensure correct port mapping

## Monitoring

### View Logs
```bash
# All pods
kubectl logs -n somens -l app=grpc-retry-fun --tail=100 -f

# Specific pod
kubectl logs -n somens <pod-name> -f
```

### Check Events
```bash
kubectl get events -n somens --sort-by='.lastTimestamp' | grep grpc-retry-fun
```

### Port Forwarding (for testing)
```bash
kubectl port-forward -n somens svc/grpc-retry-fun 50051:50051
```

## Scaling

### Horizontal Pod Autoscaler

The HPA is configured to automatically scale the deployment based on:
- CPU utilization (target: 70%)
- Memory utilization (target: 80%)

View HPA status:
```bash
kubectl get hpa -n somens
kubectl describe hpa grpc-retry-fun -n somens
```

### Manual Scaling
```bash
# Scale manually (will be overridden by HPA if it's active)
kubectl scale deployment grpc-retry-fun -n somens --replicas=3
```

Note: When HPA is active, manual scaling commands may be overridden by the autoscaler.

## Updates and Rollbacks

### Rolling Update
```bash
# Update image version (if needed)
kubectl set image deployment/grpc-retry-fun grpc-server=grpc-retry-fun:1.1 -n somens

# Monitor rollout
kubectl rollout status deployment/grpc-retry-fun -n somens
```

### Rollback
```bash
# View rollout history
kubectl rollout history deployment/grpc-retry-fun -n somens

# Rollback to previous version
kubectl rollout undo deployment/grpc-retry-fun -n somens

# Rollback to specific revision
kubectl rollout undo deployment/grpc-retry-fun --to-revision=2 -n somens
```

## Clean Up

```bash
# Delete all resources
kubectl delete -f deploy/kubernetes/ -n somens

# Or delete by label
kubectl delete all -l app=grpc-retry-fun -n somens
```

## Security Considerations

1. **Minimal Image:** Using distroless base reduces attack surface
2. **Non-root User:** Container runs as UID 65532
3. **Network Policies:** Consider adding NetworkPolicy for additional isolation
4. **Secret Management:** Use Azure Key Vault for sensitive data
5. **Image Scanning:** Regularly scan images for vulnerabilities

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [gRPC on Kubernetes](https://kubernetes.io/blog/2018/11/07/grpc-load-balancing-on-kubernetes-without-tears/)
- [Distroless Containers](https://github.com/GoogleContainerTools/distroless)

## Support

For issues or questions:
1. Check pod logs and events
2. Review Kubernetes manifest configurations
3. Verify AKS cluster connectivity
4. Check GitHub Actions workflow runs

---

**Version:** 1.0
**Last Updated:** 2024-02-14
