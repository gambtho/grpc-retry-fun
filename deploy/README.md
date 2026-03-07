# Deployment Setup — grpc-retry-fun

## Overview

This directory contains Kubernetes manifests and a GitHub Actions workflow for deploying the
`grpc-retry-fun` gRPC server to Azure Kubernetes Service (AKS).

## Stack

| Item | Value |
|------|-------|
| Language | Go 1.19 |
| Protocol | gRPC (port 50051) |
| Container image | `grpc-retry-fun:1.0` |
| Base image | `alpine:3.18` (multi-stage build from `golang:1.19-alpine`) |

## Directory structure

```
deploy/
├── kubernetes/
│   ├── namespace.yaml    # Namespace: 3-6-8pm
│   ├── deployment.yaml   # Deployment (1 replica, resource limits, probes, anti-affinity)
│   └── service.yaml      # ClusterIP Service on port 50051
└── README.md             # This file
```

## AKS target

| Setting | Value |
|---------|-------|
| Cluster | `cluster-a` |
| Resource group | `pr-314-test-rg` |
| Namespace | `3-6-8pm` |
| Service type | `ClusterIP` |

## Deployment

Deployments are triggered manually via the GitHub Actions workflow at
`.github/workflows/deploy-to-aks.yml` using `workflow_dispatch`.

### Required GitHub secrets

| Secret | Purpose |
|--------|---------|
| `AZURE_CLIENT_ID` | Federated identity client ID (OIDC) |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

### Manual trigger

1. Navigate to **Actions → Deploy to AKS** in the GitHub repository.
2. Click **Run workflow**.
3. Optionally override `cluster-name`, `resource-group`, or `namespace`.

### Dry-run validation

```bash
kubectl apply --dry-run=client -f deploy/kubernetes/
```

## Resource limits

| Resource | Request | Limit |
|----------|---------|-------|
| CPU | 100m | 500m |
| Memory | 128Mi | 512Mi |

## Health probes

All probes use `tcpSocket` on port **50051**:

| Probe | Initial Delay | Period | Failure Threshold |
|-------|--------------|--------|-------------------|
| Startup | — | 10s | 30 |
| Liveness | 15s | 20s | 3 (default) |
| Readiness | 5s | 10s | 3 (default) |
