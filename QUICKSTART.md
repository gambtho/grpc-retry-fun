# Quick Start Guide - AKS Deployment

This is a quick reference for deploying the gRPC Retry Fun application to AKS.

## Prerequisites Checklist

- [ ] Azure CLI installed and logged in
- [ ] kubectl installed
- [ ] Access to AKS cluster `thgamble_dt`
- [ ] Azure Container Registry created
- [ ] GitHub secrets configured (for CI/CD)

## Option 1: Automated Deployment (Recommended)

### Setup GitHub Secrets

Configure these secrets in GitHub repository settings:

```
AZURE_CLIENT_ID=1c65e916-5221-48f1-b437-178f0441ae61
AZURE_TENANT_ID=72f988bf-86f1-41af-91ab-2d7cd011db47
AZURE_SUBSCRIPTION_ID=d0ecd0d2-779b-4fd0-8f04-d46d07f05703
ACR_LOGIN_SERVER=<your-acr>.azurecr.io
```

### Deploy

1. Push changes to `main` branch
2. Workflow triggers automatically
3. Monitor in GitHub Actions tab

## Option 2: Manual Deployment

### Step-by-Step

```bash
# 1. Login to Azure
az login
az account set --subscription d0ecd0d2-779b-4fd0-8f04-d46d07f05703

# 2. Set variables (UPDATE ACR_NAME)
export ACR_NAME="<your-acr-name>"
export ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"
export IMAGE_NAME="grpc-retry-fun"
export IMAGE_TAG="1.0"

# 3. Build Docker image
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .

# 4. Tag for ACR
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}

# 5. Login to ACR and push
az acr login --name ${ACR_NAME}
docker push ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}

# 6. Get AKS credentials
az aks get-credentials \
  --resource-group thgamble_dt_group \
  --name thgamble_dt

# 7. Update deployment with ACR image
sed -i "s|image: grpc-retry-fun:1.0|image: ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}|g" \
  deploy/kubernetes/deployment.yaml

# 8. Deploy to AKS
kubectl apply -f deploy/kubernetes/ -n somens

# 9. Verify deployment
kubectl rollout status deployment/grpc-retry-fun -n somens
kubectl get pods -n somens -l app=grpc-retry-fun
kubectl get service -n somens grpc-retry-fun
```

## Option 3: Local Development (kind/minikube)

```bash
# Build image
docker build -t grpc-retry-fun:1.0 .

# For kind: Load into cluster
kind load docker-image grpc-retry-fun:1.0

# For minikube: Use minikube's Docker daemon
eval $(minikube docker-env)
docker build -t grpc-retry-fun:1.0 .

# Deploy
kubectl apply -f deploy/kubernetes/namespace.yaml
kubectl apply -f deploy/kubernetes/deployment-local.yaml -n somens

# Access service
kubectl port-forward -n somens service/grpc-retry-fun-local 50051:50051
```

## Verification Commands

```bash
# Check pods
kubectl get pods -n somens -l app=grpc-retry-fun -o wide

# Check service
kubectl get service -n somens grpc-retry-fun

# View logs
kubectl logs -n somens -l app=grpc-retry-fun --tail=50 -f

# Check events
kubectl get events -n somens --sort-by='.lastTimestamp'

# Describe deployment
kubectl describe deployment grpc-retry-fun -n somens
```

## Testing the gRPC Server

```bash
# Port-forward to local machine
kubectl port-forward -n somens service/grpc-retry-fun 50051:50051

# In another terminal, test with grpc_cli (if installed)
grpc_cli call localhost:50051 helloworld.Greeter.SayHello "name: 'World'"

# Or use the greeter_client from this repo
go run ./greeter_client -name=test
```

## Troubleshooting Quick Reference

| Issue | Command |
|-------|---------|
| Pods not starting | `kubectl describe pod -n somens -l app=grpc-retry-fun` |
| Image pull errors | `kubectl get events -n somens` |
| Service not accessible | `kubectl get endpoints -n somens grpc-retry-fun` |
| View logs | `kubectl logs -n somens -l app=grpc-retry-fun` |
| Delete and redeploy | `kubectl delete -f deploy/kubernetes/ -n somens && kubectl apply -f deploy/kubernetes/ -n somens` |

## ACR Permissions

Ensure the service principal has these permissions:

```bash
# Get ACR resource ID
ACR_ID=$(az acr show --name ${ACR_NAME} --query id --output tsv)

# Assign AcrPush role
az role assignment create \
  --assignee 1c65e916-5221-48f1-b437-178f0441ae61 \
  --role AcrPush \
  --scope ${ACR_ID}

# Assign AcrPull role (for AKS)
az role assignment create \
  --assignee 1c65e916-5221-48f1-b437-178f0441ae61 \
  --role AcrPull \
  --scope ${ACR_ID}
```

## Configuration Summary

| Setting | Value |
|---------|-------|
| Cluster | thgamble_dt |
| Resource Group | thgamble_dt_group |
| Namespace | somens |
| Port | 50051 |
| Service Type | ClusterIP |
| Replicas | 2 |
| Image Tag | 1.0 |

## Next Steps

1. ✅ Deploy application
2. Set up monitoring (Azure Monitor, Prometheus)
3. Configure autoscaling (HPA)
4. Add network policies
5. Set up ingress (if external access needed)
6. Implement blue-green or canary deployments

## Support

For detailed information, see:
- `deploy/README.md` - Comprehensive deployment guide
- `artifacts/deployment-summary.md` - Architecture overview
- GitHub Actions logs - For CI/CD troubleshooting
