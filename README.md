#### modified version of https://github.com/grpc/grpc-go/tree/master/examples/helloworld

# gRPC Hello World

A gRPC-based greeter application with retry capabilities, now with complete AKS deployment pipeline.

## 🚀 Quick Start

### Local Development

Follow these steps (Linux only):

 1. Run the server:

    ```console
    $ go run ./greeter_server
    ```

 2. Run the client in a new terminal window:

    ```console
    export GODEBUG=http2debug=2
    go run ./greeter_client -name=no_reconnect
    ```
    
 3. Run the client in a new terminal window:

    ```console
    export GODEBUG=http2debug=2
    go run ./greeter_client -name=reconnect -alive
    ```

4. In yet another terminal window:

   ```console
    sudo netstat -anp | grep greeter_c # use port from here in the line below
    sudo iptables -I INPUT -p tcp --dport <<PORT>> -j DROP
    ```
   
5. Observe the behavior in the two client terminals
   - reconnect client will have a single timeout, then reconnect
   - no_reconnect client will have repeated timeouts

## ☁️ Azure Kubernetes Service Deployment

### Quick Deploy

This repository includes a complete AKS deployment pipeline:

1. **Configure** (see [CONFIG_CHECKLIST.md](CONFIG_CHECKLIST.md)):
   - Update container image path in `deploy/kubernetes/deployment.yaml` and `.github/workflows/deploy-to-aks.yml`
   - Add GitHub secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
   - Configure Azure AD OIDC for GitHub Actions

2. **Deploy** (automatic via GitHub Actions):
   ```bash
   git add -A
   git commit -m "deploy: Deploy to AKS"
   git push origin main
   ```

3. **Verify**:
   ```bash
   kubectl get pods -n somens -l app=asdfa
   kubectl logs -n somens -l app=asdfa
   ```

### Documentation

- **[CONFIG_CHECKLIST.md](CONFIG_CHECKLIST.md)** - Pre-deployment configuration checklist
- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Comprehensive deployment guide with manual steps
- **[deploy/README.md](deploy/README.md)** - Kubernetes configuration reference

### What's Included

- ✅ **Dockerfile** - Multi-stage build, optimized for size (~23MB)
- ✅ **Kubernetes Manifests** - Deployment, Service, Namespace with full AKS configuration
- ✅ **GitHub Actions CI/CD** - Automated build, push to ACR, and deployment to AKS
- ✅ **Health Probes** - TCP liveness, readiness, and startup probes for gRPC
- ✅ **High Availability** - Pod anti-affinity and topology spread constraints
- ✅ **Security** - Minimal privileges, dropped capabilities, OIDC authentication
- ✅ **Resource Management** - CPU/memory requests and limits configured

### Architecture

```
GitHub Actions (OIDC) → Azure Container Registry → AKS Cluster
                                                      ↓
                                                  Namespace: somens
                                                      ↓
                                                  Deployment: asdfa
                                                      ↓
                                                  Service: ClusterIP (port 80)
```

### Container Configuration

- **Image**: Built with Go 1.19 on Alpine Linux
- **Size**: 23.5MB (minimal attack surface)
- **Port**: 80 (gRPC)
- **Tag**: 1.0

### Kubernetes Configuration

- **Cluster**: thgamble_dt
- **Resource Group**: thgamble_dt_group
- **Namespace**: somens
- **Replicas**: 1
- **Service Type**: ClusterIP
- **CPU**: 100m-500m
- **Memory**: 128Mi-512Mi

## 📖 Additional Resources

- [Dockerfile](Dockerfile) - Container build configuration
- [deploy/kubernetes/](deploy/kubernetes/) - Kubernetes manifests
- [.github/workflows/deploy-to-aks.yml](.github/workflows/deploy-to-aks.yml) - CI/CD pipeline
- [artifacts/](artifacts/) - Tool execution logs and deployment summary
