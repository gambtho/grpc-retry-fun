# grpc-retry-fun — AKS Deployment

## Overview

This directory contains the Kubernetes manifests and GitHub Actions workflow to deploy **grpc-retry-fun** — a Go gRPC server demonstrating retry and keepalive patterns — to Azure Kubernetes Service (AKS).

## Directory Structure

```
deploy/
└── kubernetes/
    ├── namespace.yaml        # Namespace: a-project
    ├── serviceaccount.yaml   # ServiceAccount for the workload
    ├── deployment.yaml       # Deployment (1 replica, resource limits, probes)
    └── service.yaml          # ClusterIP Service on port 80 (HTTP)

.github/
└── workflows/
    └── deploy-to-aks.yml     # GitHub Actions workflow (workflow_dispatch only)
```

## Application

| Property | Value |
|---|---|
| **Language** | Go 1.21 |
| **Protocol** | HTTP (port 80) |
| **Image** | `grpc-retry-fun:1.0` |
| **Base image** | `scratch` (8 MB, minimal attack surface) |

## AKS Configuration

| Property | Value |
|---|---|
| **Cluster** | `dt` |
| **Resource Group** | `thgamble` |
| **Namespace** | `a-project` |
| **Service Type** | `ClusterIP` |
| **Port** | `80` (HTTP) |
| **Replicas** | `1` |

## GitHub Actions Workflow

The deployment is triggered **manually** via `workflow_dispatch` only.  
No automatic push-triggered deployments.

### Required GitHub Secrets

| Secret | Description |
|---|---|
| `AZURE_CLIENT_ID` | Azure AD application (client) ID for OIDC |
| `AZURE_TENANT_ID` | Azure AD tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

### Inputs (with defaults)

| Input | Default | Description |
|---|---|---|
| `cluster-name` | `dt` | AKS cluster name |
| `resource-group` | `thgamble` | Azure resource group |
| `namespace` | `a-project` | Kubernetes namespace |

### Trigger a deployment

```bash
gh workflow run deploy-to-aks.yml \
  --field cluster-name=dt \
  --field resource-group=thgamble \
  --field namespace=a-project
```

## Local Validation

```bash
# Dry-run manifest validation
kubectl apply --dry-run=client -f deploy/kubernetes/

# Build container image locally
docker build -t grpc-retry-fun:1.0 .

# Run server locally
docker run --rm -p 80:80 grpc-retry-fun:1.0
```
