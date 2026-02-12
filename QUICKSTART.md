# Quick Start Guide - AKS Deployment

## Prerequisites Setup

### 1. Configure GitHub Secret
```bash
# In GitHub repository: Settings → Secrets and variables → Actions → New repository secret
# Name: AZURE_CLIENT_ID
# Value: <Your Azure Service Principal Client ID>
```

### 2. Verify Azure Container Registry
```bash
# Check if ACR exists in the resource group
az acr list --resource-group thgamble_dt_group --output table
```

### 3. Attach AKS to ACR (if not already done)
```bash
az aks update \
  --name thgamble_dt \
  --resource-group thgamble_dt_group \
  --attach-acr <your-acr-name>
```

## Manual Deployment (Optional)

If you want to deploy manually without GitHub Actions:

```bash
# 1. Build the Docker image
docker build -t grpc-retry-fun:1.0 .

# 2. Login to Azure
az login

# 3. Tag and push to ACR
ACR_NAME=$(az acr list --resource-group thgamble_dt_group --query "[0].name" -o tsv)
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)
docker tag grpc-retry-fun:1.0 ${ACR_LOGIN_SERVER}/grpc-retry-fun:1.0
az acr login --name $ACR_NAME
docker push ${ACR_LOGIN_SERVER}/grpc-retry-fun:1.0

# 4. Update deployment manifest
sed -i "s|image:.*|image: ${ACR_LOGIN_SERVER}/grpc-retry-fun:1.0|g" deploy/kubernetes/deployment.yaml

# 5. Get AKS credentials
az aks get-credentials --resource-group thgamble_dt_group --name thgamble_dt

# 6. Deploy to AKS
kubectl apply -f deploy/kubernetes/ -n somens

# 7. Verify deployment
kubectl get pods -n somens
kubectl get svc -n somens
kubectl logs -n somens -l app=grpc-retry-fun --tail=50
```

## Automated Deployment (GitHub Actions)

The easiest way to deploy:

```bash
# 1. Commit your changes
git add .
git commit -m "deploy: Update application"

# 2. Push to main branch
git push origin main

# 3. Monitor workflow
# Go to GitHub repository → Actions tab
# Watch the "Deploy gRPC Server to AKS" workflow

# 4. Verify in AKS (after workflow completes)
kubectl get pods -n somens
kubectl get svc -n somens
```

## Testing the Service

Since the service is ClusterIP (internal only), test from within the cluster:

```bash
# Deploy a test pod
kubectl run grpc-client -n somens --rm -it --image=golang:1.19 -- bash

# Inside the pod, test the gRPC service
# Install grpcurl or write a simple client
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
grpcurl -plaintext grpc-retry-fun-service.somens.svc.cluster.local:50051 list
```

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n somens -l app=grpc-retry-fun
kubectl describe pod <pod-name> -n somens
```

### Check pod logs
```bash
kubectl logs -n somens -l app=grpc-retry-fun --tail=100
kubectl logs -n somens -l app=grpc-retry-fun -f  # Follow logs
```

### Check service
```bash
kubectl get svc -n somens
kubectl describe svc grpc-retry-fun-service -n somens
```

### Check deployment
```bash
kubectl get deployment grpc-retry-fun -n somens
kubectl describe deployment grpc-retry-fun -n somens
```

### Force rollout restart
```bash
kubectl rollout restart deployment/grpc-retry-fun -n somens
kubectl rollout status deployment/grpc-retry-fun -n somens
```

## Useful Commands

```bash
# Scale replicas
kubectl scale deployment grpc-retry-fun -n somens --replicas=3

# Check resource usage
kubectl top pods -n somens

# Port forward for local testing
kubectl port-forward -n somens svc/grpc-retry-fun-service 50051:50051

# Delete deployment
kubectl delete -f deploy/kubernetes/ -n somens
```

## Important Notes

- **Image Tag**: Always use tag `1.0` (fixed requirement)
- **Namespace**: All resources deploy to `somens`
- **Service Type**: ClusterIP (internal access only)
- **Replicas**: 2 (for high availability)
- **Port**: 50051 (gRPC)

## Next Steps

1. ✅ Configure AZURE_CLIENT_ID secret in GitHub
2. ✅ Verify ACR exists and is attached to AKS
3. ✅ Push code to main branch to trigger deployment
4. ✅ Monitor GitHub Actions workflow
5. ✅ Verify pods are running in AKS
6. ✅ Test gRPC service internally

## Support

- **Documentation**: See `/deploy/README.md` for detailed information
- **Summary**: See `/artifacts/deployment-summary.md` for complete details
- **Workflow**: See `.github/workflows/deploy-to-aks.yml` for CI/CD configuration
