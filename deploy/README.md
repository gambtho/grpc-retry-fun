# Deployment — grpc-retry-fun

This directory contains Kubernetes manifests and supporting files to deploy
the **grpc-retry-fun** gRPC application to Azure Kubernetes Service (AKS).

## Directory layout

```
deploy/
└── kubernetes/
    ├── namespace.yaml        # Namespace: 3-6-8pm
    ├── serviceaccount.yaml   # Dedicated ServiceAccount (no automount)
    ├── deployment.yaml       # App Deployment (1 replica, resource limits, probes)
    └── service.yaml          # ClusterIP Service on port 50051 → targetPort 80
```

## Quick reference

| Setting                | Value                    |
|------------------------|--------------------------|
| AKS Cluster            | cluster-a                |
| Resource Group         | pr-314-test-rg           |
| Namespace              | 3-6-8pm                  |
| Image                  | grpc-retry-fun:1.0       |
| Service Type           | ClusterIP                |
| gRPC Port (container)  | 50051                    |
| Target Port            | 80                       |
| Replicas               | 1                        |
| CPU Request / Limit    | 100m / 500m              |
| Memory Request / Limit | 128Mi / 512Mi            |

## Manual deployment

```bash
# Authenticate against AKS
az aks get-credentials --resource-group pr-314-test-rg --name cluster-a

# Apply all manifests
kubectl apply -f deploy/kubernetes/ -n 3-6-8pm
```

## CI/CD

Deployments are triggered via the **Deploy to AKS** GitHub Actions workflow
(`/.github/workflows/deploy-to-aks.yml`).  The workflow is `workflow_dispatch`
only — it is never triggered automatically on push.

Azure credentials are provided through repository secrets using OIDC federated
identity (no long-lived client secrets):

| Secret                  | Purpose                              |
|-------------------------|--------------------------------------|
| `AZURE_CLIENT_ID`       | Managed identity / app client ID    |
| `AZURE_TENANT_ID`       | Azure AD tenant                      |
| `AZURE_SUBSCRIPTION_ID` | Target subscription                  |

## Health probes note

The Deployment configures `httpGet` probes on path `/` (port 80).  The gRPC
server itself does not expose an HTTP/1.1 endpoint; add a lightweight HTTP
health-check server (e.g. using `net/http` on a second port) or switch the
probe type to `tcpSocket` / `grpc` if you need live probe responses from the
server process.
