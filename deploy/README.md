# AKS Deployment for gRPC Greeter Application

This directory contains Kubernetes manifests for deploying the gRPC greeter application to Azure Kubernetes Service (AKS).

## Configuration

- **Cluster**: thgamble_dt
- **Resource Group**: thgamble_dt_group
- **Namespace**: somens
- **Application Name**: asdfa (placeholder - replace with descriptive name)
- **Container Image**: asdfasdf (placeholder - replace with ACR path: `<registry>.azurecr.io/<repository>:<tag>`)
- **Service Type**: ClusterIP
- **Target Port**: 80
- **Replicas**: 1

**⚠️ NOTE**: Replace placeholder values (asdfa, asdfasdf) with actual application names and container registry paths before deployment.

## Resource Specifications

### CPU and Memory
- **CPU Request**: 100m
- **CPU Limit**: 500m
- **Memory Request**: 128Mi
- **Memory Limit**: 512Mi

### Health Probes
All probes use TCP socket checks since this is a gRPC application:
- **Liveness Probe**: Enabled (port 80, initial delay 30s)
- **Readiness Probe**: Enabled (port 80, initial delay 10s)
- **Startup Probe**: Enabled (port 80, initial delay 5s)

### Security Context
- **runAsNonRoot**: false (as per requirements; consider enabling for production)
- **readOnlyRootFilesystem**: false (as per requirements; consider enabling for production)
- **allowPrivilegeEscalation**: false
- **Capabilities**: All dropped

**Note**: For enhanced security, consider setting `runAsNonRoot: true` and `readOnlyRootFilesystem: true` after verifying application compatibility.

### High Availability
- **Pod Anti-Affinity**: Enabled (prefer scheduling on different nodes)
- **Topology Spread Constraints**: Enabled (max skew 1 across hostnames)

## Manifests

1. **namespace.yaml** - Creates the `somens` namespace
2. **deployment.yaml** - Deploys the gRPC server with 1 replica
3. **service.yaml** - Exposes the deployment as a ClusterIP service on port 80

## Manual Deployment

To manually deploy to AKS:

```bash
# Authenticate with Azure
az login

# Set AKS context
az aks get-credentials --resource-group thgamble_dt_group --name thgamble_dt

# Apply manifests
kubectl apply -f deploy/kubernetes/

# Verify deployment
kubectl get pods -n somens
kubectl get service -n somens
```

## Automated Deployment

Deployment is automated via GitHub Actions workflow at `.github/workflows/deploy-to-aks.yml`.

The workflow:
- Triggers on push to main branch (when deploy/** files change)
- Can be manually triggered via workflow_dispatch
- Uses OIDC authentication with Azure
- Applies all Kubernetes manifests to the specified namespace

## Verifying the Deployment

```bash
# Check pod status
kubectl get pods -n somens -l app=asdfa

# Check service
kubectl get svc -n somens -l app=asdfa

# View logs
kubectl logs -n somens -l app=asdfa --tail=50

# Test the gRPC service (from within the cluster)
kubectl run -n somens grpc-client --rm -it --restart=Never \
  --image=fullstorydev/grpcurl:latest -- \
  -plaintext asdfa-service:80 helloworld.Greeter/SayHello
```

## Troubleshooting

### Pod not starting
```bash
kubectl describe pod -n somens -l app=asdfa
kubectl logs -n somens -l app=asdfa
```

### Service not accessible
```bash
kubectl get endpoints -n somens asdfa-service
kubectl describe svc -n somens asdfa-service
```

### Check events
```bash
kubectl get events -n somens --sort-by='.lastTimestamp'
```
