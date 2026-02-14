# AKS Deployment Configuration Summary

## Overview

This document provides a comprehensive summary of the Kubernetes deployment configuration for the gRPC Retry Fun application on Azure Kubernetes Service (AKS).

## Application Details

- **Application Name:** grpc-retry-fun
- **Image:** grpc-retry-fun:1.0 (will be pushed to ACR)
- **Port:** 50051 (gRPC)
- **Protocol:** TCP

## AKS Configuration

- **Cluster Name:** thgamble_dt
- **Resource Group:** thgamble_dt_group
- **Namespace:** somens
- **Tenant ID:** 72f988bf-86f1-41af-91ab-2d7cd011db47
- **Subscription ID:** d0ecd0d2-779b-4fd0-8f04-d46d07f05703

## Kubernetes Resources

### 1. Deployment (deployment.yaml)

**Specifications:**
- **Replicas:** 2 (for high availability)
- **Strategy:** Rolling Update (maxSurge: 1, maxUnavailable: 0)
- **Image:** grpc-retry-fun:1.0 (from ACR)
- **Container Port:** 50051 (gRPC)

**Security:**
- Non-root user (UID 65532)
- Read-only root filesystem
- All capabilities dropped
- No privilege escalation
- Seccomp profile: RuntimeDefault

**Resources:**
- CPU: 100m request, 500m limit
- Memory: 128Mi request, 256Mi limit

**Health Checks:**
- Liveness Probe: gRPC health check (port 50051)
- Readiness Probe: gRPC health check (port 50051)
- Startup Probe: gRPC health check (port 50051)

### 2. Service (service.yaml)

- **Type:** ClusterIP (internal only)
- **Port:** 50051
- **Protocol:** TCP
- **Name:** grpc-retry-fun

### 3. ConfigMap (configmap.yaml)

Configuration for gRPC server, logging, retry policies, and connection settings.

### 4. Horizontal Pod Autoscaler (hpa.yaml)

- **Min Replicas:** 2
- **Max Replicas:** 10
- **Metrics:** CPU (70%), Memory (80%)

### 5. Pod Disruption Budget (pdb.yaml)

- **Min Available:** 1 pod (ensures availability during disruptions)

## GitHub Actions Workflow

**File:** `.github/workflows/deploy-to-aks.yml`

**Triggers:**
- Push to main branch (deploy/**, Dockerfile, source code)
- Manual workflow_dispatch

**Required Secrets:**
- AZURE_CLIENT_ID
- AZURE_TENANT_ID
- AZURE_SUBSCRIPTION_ID
- ACR_NAME

**Workflow:**
1. Build and push Docker image to ACR
2. Login to AKS with OIDC
3. Deploy manifests to namespace `somens`
4. Verify deployment and display status

## Security Features

1. Non-root user (UID 65532)
2. Read-only root filesystem
3. Distroless base image (~4.2MB)
4. All capabilities dropped
5. No privilege escalation
6. Internal-only service (ClusterIP)

## High Availability

1. 2 replicas minimum
2. Pod anti-affinity (distribute across nodes)
3. Rolling updates (zero downtime)
4. Pod disruption budget
5. Horizontal autoscaling (2-10 pods)
6. gRPC health checks

## Deployment Commands

```bash
# Set AKS context
az aks get-credentials --resource-group thgamble_dt_group --name thgamble_dt

# Deploy to AKS
kubectl apply -f deploy/kubernetes/ -n somens

# Verify deployment
kubectl get all -n somens -l app=grpc-retry-fun
kubectl get hpa,pdb -n somens
```

## Troubleshooting

- Check logs: `kubectl logs -n somens -l app=grpc-retry-fun`
- Describe pods: `kubectl describe pod -n somens -l app=grpc-retry-fun`
- View events: `kubectl get events -n somens --sort-by='.lastTimestamp'`
- Check HPA: `kubectl describe hpa grpc-retry-fun -n somens`

---

**Version:** 1.0
**Generated:** 2024-02-14
