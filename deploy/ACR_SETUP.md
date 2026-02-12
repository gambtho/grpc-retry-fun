# Azure Container Registry (ACR) Setup Guide

This guide explains how to set up Azure Container Registry for the grpc-retry-fun application deployment.

## Why Use ACR?

Azure Container Registry (ACR) is the recommended way to store and distribute Docker images for AKS deployments because:
- Integrated with Azure and AKS
- Secure, private registry
- Low latency image pulls from AKS
- Built-in vulnerability scanning
- Managed service with high availability

## Prerequisites

- Azure CLI installed
- Access to the Azure subscription (d0ecd0d2-779b-4fd0-8f04-d46d07f05703)
- Permissions to create ACR and modify AKS cluster

## Step 1: Create Azure Container Registry

```bash
# Set variables
ACR_NAME="<your-unique-acr-name>"  # Must be globally unique, alphanumeric only
RESOURCE_GROUP="thgamble_dt_group"
LOCATION="<your-location>"  # e.g., eastus, westus2, etc.

# Create the ACR
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --location $LOCATION

# Verify creation
az acr show --name $ACR_NAME --query loginServer --output tsv
# Output: <acr-name>.azurecr.io
```

## Step 2: Attach ACR to AKS Cluster

```bash
# Attach ACR to AKS (enables AKS to pull images without credentials)
az aks update \
  --name thgamble_dt \
  --resource-group thgamble_dt_group \
  --attach-acr $ACR_NAME

# Verify the attachment
az aks check-acr \
  --name thgamble_dt \
  --resource-group thgamble_dt_group \
  --acr $ACR_NAME.azurecr.io
```

## Step 3: Build and Push Image to ACR

### Option A: Local Build and Push

```bash
# Login to ACR
az acr login --name $ACR_NAME

# Build and tag the image
docker build -t $ACR_NAME.azurecr.io/grpc-retry-fun:1.0 .

# Push to ACR
docker push $ACR_NAME.azurecr.io/grpc-retry-fun:1.0

# List images in ACR
az acr repository list --name $ACR_NAME --output table
az acr repository show-tags --name $ACR_NAME --repository grpc-retry-fun --output table
```

### Option B: Build in ACR (ACR Tasks)

```bash
# Build directly in ACR (no local Docker needed)
az acr build \
  --registry $ACR_NAME \
  --image grpc-retry-fun:1.0 \
  --file Dockerfile \
  .
```

## Step 4: Update Kubernetes Deployment

Update the image reference in `deploy/kubernetes/deployment.yaml`:

```yaml
spec:
  containers:
  - name: greeter-server
    image: <your-acr-name>.azurecr.io/grpc-retry-fun:1.0
    imagePullPolicy: Always
```

## Step 5: Update GitHub Actions Workflow

Update `.github/workflows/deploy-to-aks.yml`:

```yaml
env:
  CLUSTER_NAME: thgamble_dt
  CLUSTER_RESOURCE_GROUP: thgamble_dt_group
  NAMESPACE: somens
  IMAGE_NAME: grpc-retry-fun
  IMAGE_TAG: "1.0"
  ACR_NAME: <your-acr-name>  # Add your ACR name here
```

No other changes needed! The workflow already has conditional logic to use ACR when `ACR_NAME` is set.

## Step 6: Grant GitHub Actions Access to ACR (Optional)

If using OIDC federated identity, ensure the identity has access to ACR:

```bash
# Get the identity object ID
IDENTITY_ID="1c65e916-5221-48f1-b437-178f0441ae61"

# Get ACR resource ID
ACR_ID=$(az acr show --name $ACR_NAME --query id --output tsv)

# Assign AcrPush role (allows push and pull)
az role assignment create \
  --assignee $IDENTITY_ID \
  --role AcrPush \
  --scope $ACR_ID
```

## Step 7: Deploy to AKS

```bash
# Apply the updated deployment
kubectl apply -f deploy/kubernetes/deployment.yaml -n somens

# Or apply all manifests
kubectl apply -f deploy/kubernetes/ -n somens

# Verify the deployment
kubectl get pods -n somens -l app=grpc-retry-fun
kubectl describe pod <pod-name> -n somens | grep -A 5 "Events:"
```

## Verification

Check that pods are pulling from ACR:

```bash
# Check pod events
kubectl get events -n somens --sort-by='.lastTimestamp'

# Check image pull status
kubectl get pods -n somens -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].image}{"\t"}{.status.containerStatuses[0].imageID}{"\n"}{end}'
```

Expected output should show your ACR image:
```
grpc-retry-fun-xxxxx    <acr-name>.azurecr.io/grpc-retry-fun:1.0    docker-pullable://<acr-name>.azurecr.io/grpc-retry-fun@sha256:...
```

## Troubleshooting

### Image Pull Errors

If pods show `ImagePullBackOff` or `ErrImagePull`:

```bash
# Check pod events
kubectl describe pod <pod-name> -n somens

# Common issues:
# 1. ACR not attached to AKS
az aks show --name thgamble_dt --resource-group thgamble_dt_group --query servicePrincipalProfile

# 2. Image doesn't exist in ACR
az acr repository show --name $ACR_NAME --repository grpc-retry-fun

# 3. Wrong image tag
az acr repository show-tags --name $ACR_NAME --repository grpc-retry-fun
```

### Authentication Issues

```bash
# Test ACR authentication from AKS
kubectl run test-acr --image=$ACR_NAME.azurecr.io/grpc-retry-fun:1.0 --restart=Never -n somens
kubectl get pods test-acr -n somens
kubectl describe pod test-acr -n somens
kubectl delete pod test-acr -n somens
```

## Cost Optimization

ACR pricing tiers:
- **Basic**: ~$5/month - Good for development and testing
- **Standard**: ~$20/month - Production workloads
- **Premium**: ~$50/month - Geo-replication, advanced security

```bash
# Check current SKU
az acr show --name $ACR_NAME --query sku.name

# Upgrade if needed
az acr update --name $ACR_NAME --sku Standard
```

## Security Best Practices

1. **Enable vulnerability scanning** (Premium SKU):
```bash
az acr task create \
  --registry $ACR_NAME \
  --name securityScan \
  --context /dev/null \
  --cmd "echo Scan complete" \
  --timeout 1800
```

2. **Enable content trust**:
```bash
export DOCKER_CONTENT_TRUST=1
docker push $ACR_NAME.azurecr.io/grpc-retry-fun:1.0
```

3. **Use managed identity** (already configured in this setup)

4. **Enable Azure Defender for ACR**:
```bash
az security pricing create --name ContainerRegistry --tier Standard
```

## Alternative: Using Image Pull Secrets

If you can't attach ACR to AKS, use image pull secrets:

```bash
# Create service principal
ACR_SP=$(az ad sp create-for-rbac --name grpc-retry-fun-acr-sp --skip-assignment)
ACR_SP_ID=$(echo $ACR_SP | jq -r '.appId')
ACR_SP_PASSWORD=$(echo $ACR_SP | jq -r '.password')

# Assign AcrPull role
az role assignment create --assignee $ACR_SP_ID --role AcrPull --scope $(az acr show --name $ACR_NAME --query id --output tsv)

# Create Kubernetes secret
kubectl create secret docker-registry acr-secret \
  --docker-server=$ACR_NAME.azurecr.io \
  --docker-username=$ACR_SP_ID \
  --docker-password=$ACR_SP_PASSWORD \
  -n somens

# Update deployment to use the secret
kubectl patch deployment grpc-retry-fun -n somens \
  -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"acr-secret"}]}}}}'
```

## Summary

Once ACR is configured:
1. Images are automatically pulled by AKS
2. GitHub Actions can build and push to ACR
3. Deployments will use the ACR image
4. No manual image distribution needed

For questions or issues, refer to the [Azure ACR documentation](https://docs.microsoft.com/en-us/azure/container-registry/).
