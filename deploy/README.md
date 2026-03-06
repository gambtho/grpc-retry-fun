# Deployment Guide — grpc-retry-fun on AKS

## Overview

This directory contains Kubernetes manifests for deploying the `grpc-retry-fun`
gRPC server to Azure Kubernetes Service (AKS).

## Directory structure

```
deploy/
└── kubernetes/
    ├── namespace.yaml       # Namespace: new
    ├── serviceaccount.yaml  # ServiceAccount with Workload Identity annotation
    ├── deployment.yaml      # Deployment (1 replica, resource limits, probes)
    └── service.yaml         # ClusterIP Service on port 50051
```

## Prerequisites

| Item | Value |
|------|-------|
| AKS Cluster | `cluster-a` |
| Resource Group | `pr-314-test-rg` |
| Namespace | `new` |
| Subscription | `d98169bc-2d4a-491b-98cb-b69cbf002eb0` |
| Azure Tenant | `b06f66c5-f30b-4797-8dec-52cc6568e9aa` |

### Required GitHub Actions secrets

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Client ID of the User-Assigned Managed Identity / App Registration used for OIDC |
| `AZURE_TENANT_ID` | Azure AD tenant ID (`b06f66c5-f30b-4797-8dec-52cc6568e9aa`) |
| `ACR_LOGIN_SERVER` | ACR login server, e.g. `myregistry.azurecr.io` |

## CI/CD workflow

The workflow at `.github/workflows/deploy-to-aks.yml` is triggered exclusively
via **`workflow_dispatch`** — no automatic push triggers. It:

1. Builds the multi-stage Docker image and pushes it to ACR tagged with the
   commit SHA.
2. Logs in to Azure using OIDC (no long-lived credentials stored).
3. Sets the AKS context and applies all manifests under `deploy/kubernetes/`.
4. Annotates every Deployment in the namespace with the GitHub Actions run URL
   for traceability.
5. Waits for the rollout to complete successfully.

## Manual deployment

```bash
# Authenticate
az login
az aks get-credentials --resource-group pr-314-test-rg --name cluster-a

# Apply all manifests
kubectl apply -f deploy/kubernetes/ -n new

# Verify
kubectl rollout status deployment/grpc-retry-fun -n new
kubectl get pods -n new -l app.kubernetes.io/name=grpc-retry-fun
```

## Port information

The gRPC server listens on **port 50051** (TCP). The Kubernetes Service exposes
this as a `ClusterIP` on the same port. To test from within the cluster:

```bash
# Port-forward for local testing
kubectl port-forward svc/grpc-retry-fun 50051:50051 -n new
```

## Health probes

The probes currently use `tcpSocket` checks against port 50051, which verify
that the gRPC listener is accepting connections.  
To upgrade to full gRPC health checking (recommended), implement the
[gRPC Health Checking Protocol](https://grpc.github.io/grpc/core/md_doc_health-checking.html)
in the server and switch the probes to `grpcAction`.
