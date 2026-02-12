#### modified version of https://github.com/grpc/grpc-go/tree/master/examples/helloworld

# gRPC Hello World

## 🚀 Quick Start

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

---

## 🐳 Docker & Kubernetes Deployment

This repository includes a complete production-ready deployment pipeline for Azure Kubernetes Service (AKS).

### Features
- ✅ Multi-stage Dockerfile with distroless runtime (11.2MB image)
- ✅ Security hardening (non-root, read-only FS, dropped capabilities)
- ✅ Kubernetes manifests with health checks and resource limits
- ✅ GitHub Actions CI/CD with OIDC authentication
- ✅ Automated deployment to AKS

### Quick Deploy

#### Using Docker
```bash
# Build the image
docker build -t grpc-retry-fun:1.0 .

# Run the container
docker run -p 50051:50051 grpc-retry-fun:1.0
```

#### Deploy to AKS
```bash
# See comprehensive deployment guide
cat deploy/README.md

# Or run the validation script
./validate-deployment.sh

# Apply to AKS
kubectl apply -f deploy/kubernetes/ -n somens
```

### Documentation
- 📖 [Deployment Guide](deploy/README.md) - Complete AKS deployment documentation
- 📊 [Deployment Summary](artifacts/DEPLOYMENT_SUMMARY.md) - Quick reference
- 🔒 [Security Summary](artifacts/SECURITY_SUMMARY.md) - Security analysis and compliance
- ✅ [Tool Checklist](artifacts/tool-call-checklist.md) - Deployment workflow tracking

### CI/CD
The repository includes a GitHub Actions workflow (`.github/workflows/deploy-to-aks.yml`) that automatically:
1. Builds the Docker image
2. Pushes to GitHub Container Registry
3. Deploys to AKS cluster `thgamble_dt` in namespace `somens`

**Required Secrets**:
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

For more details, see the [deployment documentation](deploy/README.md).

---

## 🛠️ Development

### Prerequisites
- Go 1.19+
- Docker (optional, for containerization)
- kubectl (optional, for Kubernetes deployment)

### Building Locally
```bash
# Build the server
go build -o greeter_server ./greeter_server/

# Run the server
./greeter_server --port=50051
```

### Running Tests
```bash
go test ./...
```

---

## 📝 License

Apache License 2.0 - See [LICENSE](LICENSE) for details
