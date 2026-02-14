# Configuration Checklist

Before deploying, replace the following placeholder values with actual values:

## Required Changes

### 1. Container Image Path
**Location**: Multiple files
- `deploy/kubernetes/deployment.yaml` (line ~45): `image: asdfasdf`
- `.github/workflows/deploy-to-aks.yml` (line ~22): `IMAGE_NAME: asdfasdf`

**Replace with**: Your actual Azure Container Registry path
```
Format: <registry-name>.azurecr.io/<repository-name>
Example: myregistry.azurecr.io/grpc-greeter
```

### 2. GitHub Secrets
**Location**: GitHub Repository Settings → Secrets and variables → Actions

Add the following secrets:
- `AZURE_CLIENT_ID`: Your Azure AD application client ID (not the placeholder '123123')
- `AZURE_TENANT_ID`: 72f988bf-86f1-41af-91ab-2d7cd011db47
- `AZURE_SUBSCRIPTION_ID`: d0ecd0d2-779b-4fd0-8f04-d46d07f05703

### 3. Application and Resource Names (Optional)
These are currently set as specified in requirements but can be changed:

**Namespace**: `somens` → Consider using a descriptive name like `grpc-greeter`
- `deploy/kubernetes/namespace.yaml` (line 3)
- `deploy/kubernetes/deployment.yaml` (line 5)
- `deploy/kubernetes/service.yaml` (line 4)
- `.github/workflows/deploy-to-aks.yml` (line 20)

**Application Name**: `asdfa` → Consider using a descriptive name like `grpc-greeter-app`
- `deploy/kubernetes/deployment.yaml` (lines 3, 7, 14, 24, 31, 41)
- `deploy/kubernetes/service.yaml` (lines 3, 6, 10)

## Optional Security Enhancements

### Enhanced Security Context
**Location**: `deploy/kubernetes/deployment.yaml` (lines ~60-64)

Current settings (as per requirements):
```yaml
securityContext:
  allowPrivilegeEscalation: false
  runAsNonRoot: false
  readOnlyRootFilesystem: false
```

**Consider for production**:
```yaml
securityContext:
  allowPrivilegeEscalation: false
  runAsNonRoot: true
  runAsUser: 1000
  runAsGroup: 1000
  readOnlyRootFilesystem: true
  capabilities:
    drop:
    - ALL
```

**Note**: If enabling `readOnlyRootFilesystem: true`, ensure the application doesn't need write access to the filesystem. If it does, mount emptyDir volumes for writable directories.

## Verification Checklist

Before deployment, verify:
- [ ] Container image path updated in deployment.yaml
- [ ] Container image path updated in deploy-to-aks.yml
- [ ] GitHub secrets configured (AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID)
- [ ] Azure AD application configured with OIDC federated credentials
- [ ] AKS cluster access verified: `az aks get-credentials --resource-group thgamble_dt_group --name thgamble_dt`
- [ ] Namespace name is appropriate (or kept as specified)
- [ ] Application labels are descriptive (or kept as specified)
- [ ] Security context settings reviewed and adjusted if needed
- [ ] Resource limits appropriate for your workload
- [ ] Health probe settings appropriate for your application startup time

## Quick Deployment Test

After making changes, validate before committing:

```bash
# 1. Validate YAML syntax
for file in deploy/kubernetes/*.yaml; do 
  python3 -c "import yaml; yaml.safe_load(open('$file'))"
done

# 2. Test Docker build
docker build -t grpc-retry-fun:1.0 .

# 3. Test local run (optional)
docker run -p 8080:80 grpc-retry-fun:1.0

# 4. Dry-run Kubernetes manifests (if connected to cluster)
kubectl apply --dry-run=client -f deploy/kubernetes/
```

## Post-Deployment Verification

After deploying to AKS:

```bash
# Check deployment status
kubectl rollout status deployment/asdfa-deployment -n somens

# Check pods
kubectl get pods -n somens -l app=asdfa

# Check service
kubectl get svc -n somens asdfa-service

# View logs
kubectl logs -n somens -l app=asdfa --tail=50

# Test gRPC service
kubectl run -n somens grpc-test --rm -it --restart=Never \
  --image=fullstorydev/grpcurl:latest -- \
  -plaintext asdfa-service:80 helloworld.Greeter/SayHello
```
