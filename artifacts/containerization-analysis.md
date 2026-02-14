# Containerization Analysis: grpc-retry-fun

## Repository Overview

**Repository Name:** grpc-retry-fun  
**Type:** Go gRPC Server Application  
**Primary Language:** Go 1.19+  
**Available Go Version:** Go 1.24.13 (compatible)

## Application Structure

### Main Components

1. **gRPC Server** (`greeter_server/main.go`)
   - Implements a Greeter service
   - Listens on port **50051** (configurable via `-port` flag)
   - Uses gRPC protocol for communication
   - Implements `SayHello` RPC method

2. **gRPC Client** (`greeter_client/main.go`)
   - Test client for the server
   - Demonstrates reconnection behavior
   - Not required for containerization

3. **Protocol Buffers** (`helloworld/`)
   - Contains generated protobuf code
   - `helloworld.pb.go` - Message definitions
   - `helloworld_grpc.pb.go` - gRPC service definitions
   - `helloworld.proto` - Proto definition file

## Dependencies Analysis

### Go Module Information
- **Module Name:** `helloworld`
- **Go Version:** 1.19 (minimum)

### Key Dependencies
```
google.golang.org/grpc v1.57.0              # gRPC framework
google.golang.org/grpc/examples v0.0.0     # Example protos
google.golang.org/protobuf v1.31.0         # Protocol buffers
github.com/grpc-ecosystem/go-grpc-middleware v1.4.0  # Middleware
```

### Indirect Dependencies
- golang.org/x/net
- golang.org/x/sys
- golang.org/x/text
- google.golang.org/genproto

## Build Process

### Current Build Commands
```bash
# Download dependencies
go mod download

# Build server binary
go build -o server ./greeter_server/main.go

# Run server
./server -port=50051
```

### Build Results
- **Binary Size:** ~15MB (uncompressed)
- **Build Time:** < 10 seconds
- **Build Success:** ✅ Verified

## Network Configuration

- **Protocol:** gRPC over TCP
- **Default Port:** 50051
- **Port Configuration:** Command-line flag `-port`
- **Listen Address:** `0.0.0.0` (all interfaces)

## Containerization Recommendations

### 1. Multi-Stage Docker Build
**Recommended Approach:**
- **Build Stage:** Use `golang:1.19-alpine` or later
- **Runtime Stage:** Use `alpine:latest` or `distroless/static`
- **Benefits:** Minimal image size, security hardening

### 2. Image Optimization
- Use multi-stage build to separate build dependencies from runtime
- Expected final image size: **< 25MB** (with Alpine) or **< 20MB** (with distroless)
- Enable Go binary optimizations: `-ldflags="-w -s"` to strip debug info

### 3. Security Considerations
- Run as non-root user (UID 1000 or similar)
- Use minimal base image (Alpine or distroless)
- No CGO dependencies detected - can use static binary
- EXPOSE port 50051 in Dockerfile

### 4. Build Strategy
```dockerfile
# Build stage
FROM golang:1.19-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o server ./greeter_server/main.go

# Runtime stage
FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/server .
EXPOSE 50051
CMD ["./server"]
```

### 5. Environment Variables
- **PORT:** Could be added for flexible port configuration
- **LOG_LEVEL:** For production logging control
- Currently uses command-line flags; may need wrapper script for env vars

## Kubernetes Deployment Considerations

### Service Configuration
- **Type:** ClusterIP (as specified in requirements)
- **Port:** 50051
- **Protocol:** TCP
- **Health Checks:** May need to implement gRPC health check protocol

### Resource Requirements
- **CPU:** Minimal (start with 100m request, 500m limit)
- **Memory:** ~50-100MB (start with 128Mi request, 256Mi limit)
- **Replicas:** Start with 2 for HA

### Deployment Strategy
- **Rolling Update:** maxUnavailable: 0, maxSurge: 1
- **Readiness Probe:** TCP socket check on port 50051
- **Liveness Probe:** TCP socket check on port 50051

### ConfigMap/Secrets
- No sensitive data detected in code
- Port configuration can use ConfigMap
- No database or external service credentials needed

## AKS-Specific Recommendations

### Target Configuration
- **Cluster:** thgamble_dt
- **Resource Group:** thgamble_dt_group
- **Namespace:** somens
- **Service Type:** ClusterIP

### Naming Convention
- **Deployment:** `grpc-retry-fun`
- **Service:** `grpc-retry-fun-service`
- **ConfigMap:** `grpc-retry-fun-config` (if needed)

### Network Policy
- Allow ingress on port 50051 from within namespace
- Consider using Azure Service Mesh for advanced traffic management

## CI/CD Pipeline Requirements

### GitHub Actions Workflow
1. **Build Step:**
   - Checkout code
   - Build Docker image
   - Tag with version (1.0)
   
2. **Authentication:**
   - Use Azure OIDC with federated credentials
   - Client ID, Tenant ID, Subscription ID from secrets
   
3. **Deployment:**
   - Use azure/login@v2
   - Use azure/aks-set-context@v4
   - Apply manifests: `kubectl apply -f deploy/kubernetes/ -n somens`

4. **Triggers:**
   - Push to main (paths: deploy/**)
   - workflow_dispatch for manual runs

## Testing Strategy

### Pre-Deployment Testing
```bash
# Build and run locally
docker build -t grpc-retry-fun:1.0 .
docker run -p 50051:50051 grpc-retry-fun:1.0

# Test with client
go run ./greeter_client -name=test
```

### Validation Commands
```bash
# Validate Kubernetes manifests
kubectl apply --dry-run=client -f deploy/kubernetes/

# Check deployment status
kubectl get pods -n somens -l app=grpc-retry-fun
kubectl logs -n somens -l app=grpc-retry-fun

# Test service connectivity
kubectl run test-pod --rm -it --image=alpine --namespace=somens -- sh
# Inside pod: nc -zv grpc-retry-fun-service 50051
```

## Potential Issues and Mitigations

### Issue 1: gRPC Health Checking
- **Problem:** No health check endpoint implemented
- **Mitigation:** Use TCP socket probe or implement gRPC health protocol

### Issue 2: Graceful Shutdown
- **Problem:** Server may not handle SIGTERM gracefully
- **Mitigation:** May need to add signal handling for clean shutdown

### Issue 3: Binary Size
- **Problem:** Go binaries can be large
- **Mitigation:** Use build flags `-ldflags="-w -s"` and multi-stage build

### Issue 4: Static vs Dynamic Linking
- **Problem:** CGO dependencies would require additional libraries
- **Mitigation:** Verified CGO_ENABLED=0 works; no CGO dependencies

## Next Steps

1. ✅ Repository analysis complete
2. ⏳ Generate Dockerfile with multi-stage build
3. ⏳ Fix and optimize Dockerfile
4. ⏳ Build Docker image (tag: 1.0)
5. ⏳ Scan image for vulnerabilities
6. ⏳ Generate Kubernetes manifests for AKS
7. ⏳ Create GitHub Actions deployment workflow
8. ⏳ Validate all configurations

## Summary

This is a straightforward Go gRPC server application that is well-suited for containerization. The application:
- ✅ Has no external dependencies (no database, cache, etc.)
- ✅ Uses standard gRPC protocol
- ✅ Has simple build process
- ✅ Can produce small, efficient container images
- ✅ Is stateless and horizontally scalable
- ✅ Builds successfully with current toolchain

**Recommended Image Strategy:** Multi-stage build with Alpine or distroless base
**Expected Final Image Size:** < 25MB
**Deployment Complexity:** Low
**Production Readiness:** Good (may need health checks and graceful shutdown)
