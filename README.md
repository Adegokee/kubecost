# Kubecost Deployment via ArgoCD

This repository contains the ArgoCD configuration to deploy Kubecost using Helm charts under the Platform-Tools project.

## Quick Start - Choose Your Deployment Method

### Method 1: Direct Helm Chart (Recommended for immediate deployment)

Use the direct Helm chart application for the quickest deployment:

```bash
# Apply the direct Helm-based ArgoCD Application
kubectl apply -f platform-tools/kubecost/base/application-helm-direct.yaml
```

### Method 2: GitOps with Kustomize (Recommended for production)

1. Push this repository structure to your GitOps repository: `https://github.com/Adegokee/kubecost.git`
2. Update the repository URL in the application manifests
3. Apply the GitOps-based application:

```bash
# For development
kubectl apply -f platform-tools/kubecost/overlays/development/application-dev.yaml

# For production  
kubectl apply -f platform-tools/kubecost/base/application-gitops.yaml
```

## Repository Structure
            ├── development/
            │   ├── kustomization.yaml          # Dev environment overlay
            │   └── values-dev.yaml             # Dev-specific values
            ├── staging/
            │   ├── kustomization.yaml          # Staging environment overlay
            │   └── values-staging.yaml         # Staging-specific values
            └── production/
                ├── kustomization.yaml          # Production environment overlay
                └── values-production.yaml      # Production-specific values


# Kubecost Deployment via ArgoCD

This repository contains the ArgoCD application configuration for deploying Kubecost to Kubernetes clusters using the official Helm chart under the platform-tools project.

## Overview

Kubecost provides cost visibility, allocation, and optimization insights for Kubernetes clusters. This deployment:
- Uses ArgoCD for GitOps-driven lifecycle management
- Deploys into the `kubecost` namespace
- Provides cost allocation by namespace, workload, and labels
- Enables optimization recommendations for right-sizing and cluster efficiency
- Supports multiple environments (development, staging, production)

## Architecture

```
platform-tools/
└── kubecost/
    ├── base/
    │   ├── kustomization.yaml          # Base kustomization config
    │   ├── application.yaml            # ArgoCD Application manifest  
    │   ├── namespace.yaml              # Namespace and RBAC resources
    │   └── values.yaml                 # Base Helm values
    └── overlays/
        ├── development/
        │   ├── kustomization.yaml      # Development overlay
        │   └── values-dev.yaml         # Development-specific values
        ├── staging/
        │   ├── kustomization.yaml      # Staging overlay
        │   └── values-staging.yaml     # Staging-specific values
        └── production/
            ├── kustomization.yaml      # Production overlay
            └── values-production.yaml  # Production-specific values
```

## Prerequisites

1. **ArgoCD** installed and configured in the cluster
2. **platform-tools** project exists in ArgoCD
3. **Ingress Controller** (nginx recommended) for UI access
4. **Cert Manager** for TLS certificate automation (optional)
5. **Prometheus** for metrics collection (can use built-in or external)

## Deployment Steps

### Step 1: Update Configuration

1. **Update Domain Names**:
   Edit the ingress host values in the environment-specific values files:
   ```yaml
   # In values-dev.yaml, values-staging.yaml, values-production.yaml
   - name: ingress.hosts[0].host
     value: "kubecost-dev.your-domain.com"  # Replace with actual domain
   ```

2. **Configure Storage Class** (if needed):
   Update the storage class in `base/values.yaml`:
   ```yaml
   persistentVolume:
     storageClass: "your-storage-class"  # Set appropriate storage class
   ```

3. **Set Kubecost Token** (for Enterprise features):
   Update the kubecostToken parameter in production values:
   ```yaml
   - name: kubecostToken
     value: "your-enterprise-token"  # Set your Kubecost enterprise token
   ```

### Step 2: Apply to ArgoCD

Choose one of the following methods:

#### Method A: Direct Application
```bash
# Apply the development environment
kubectl apply -k overlays/development/

# Apply the staging environment  
kubectl apply -k overlays/staging/

# Apply the production environment
kubectl apply -k overlays/production/
```

#### Method B: ArgoCD CLI
```bash
# Create ArgoCD application for development
argocd app create kubecost-dev \\
  --repo https://git.edusuc.net/WEBFORX/ArgoCD-gitops \\
  --path platform-tools/kubecost/overlays/development \\
  --dest-server https://kubernetes.default.svc \\
  --dest-namespace kubecost \\
  --project platform-tools \\
  --sync-policy automated
```

#### Method C: ArgoCD UI
1. Navigate to ArgoCD UI
2. Click "+ NEW APP"
3. Fill in the application details:
   - **Application Name**: kubecost
   - **Project**: platform-tools
   - **Repository URL**: https://git.edusuc.net/WEBFORX/ArgoCD-gitops
   - **Path**: platform-tools/kubecost/overlays/production (or desired environment)
   - **Cluster URL**: https://kubernetes.default.svc
   - **Namespace**: kubecost
4. Enable auto-sync if desired
5. Click "CREATE"

### Step 3: Verify Deployment

1. **Check ArgoCD Application Status**:
   ```bash
   argocd app get kubecost
   ```

2. **Verify Pods are Running**:
   ```bash
   kubectl get pods -n kubecost
   ```

3. **Check Services**:
   ```bash
   kubectl get svc -n kubecost
   ```

4. **Verify Ingress** (if configured):
   ```bash
   kubectl get ingress -n kubecost
   ```

## Accessing Kubecost

### Via Ingress (Recommended)
If ingress is configured, access Kubecost at:
- Development: https://kubecost-dev.your-domain.com
- Staging: https://kubecost-staging.your-domain.com  
- Production: https://kubecost.your-domain.com

### Via Port Forward
```bash
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090
```
Then access at: http://localhost:9090

### Via LoadBalancer
If using LoadBalancer service type, get the external IP:
```bash
kubectl get svc -n kubecost kubecost-cost-analyzer
```

## Configuration Options

### Cost Allocation Features

Kubecost provides several cost allocation views:

1. **By Namespace**: View costs broken down by Kubernetes namespace
2. **By Workload**: See costs for deployments, statefulsets, daemonsets
3. **By Label**: Allocate costs based on custom labels
4. **By Service**: Track costs per Kubernetes service

### Optimization Features

1. **Right-sizing Recommendations**: Suggests optimal CPU/memory requests
2. **Unused Resource Detection**: Identifies unutilized resources
3. **Cluster Efficiency Metrics**: Overall cluster utilization insights

### Integration Options

- **Prometheus Integration**: Uses Prometheus for metrics collection
- **Grafana Dashboards**: Pre-built dashboards for visualization
- **Slack/Teams Alerts**: Cost anomaly notifications
- **CSV/API Export**: Export cost data for external analysis

## Environment-Specific Settings

### Development
- Reduced resource requests/limits
- Smaller persistent volume (5Gi)
- Debug logging enabled
- Single replica

### Staging  
- Medium resource allocation
- Standard persistent volume (8Gi)
- Info level logging
- Single replica

### Production
- Full resource allocation
- Large persistent volume (20Gi)
- Error level logging only
- High availability (2 replicas)
- Enterprise features enabled

## Monitoring and Alerts

### Metrics Exposed
Kubecost exposes Prometheus metrics at `/metrics` endpoint on port 9003:
- Cost allocation metrics
- Resource utilization metrics  
- Right-sizing recommendations

### Health Checks
- **Readiness Probe**: `/readyz` on port 9090
- **Liveness Probe**: `/healthz` on port 9090

## Troubleshooting

### Common Issues

1. **Pod Not Starting**:
   ```bash
   kubectl describe pod -n kubecost -l app.kubernetes.io/name=kubecost
   kubectl logs -n kubecost -l app.kubernetes.io/name=kubecost
   ```

2. **ArgoCD Sync Failures**:
   ```bash
   argocd app get kubecost
   argocd app sync kubecost
   ```

3. **Permission Issues**:
   ```bash
   kubectl auth can-i --list --as=system:serviceaccount:kubecost:kubecost-cost-analyzer
   ```

4. **Ingress Not Working**:
   ```bash
   kubectl describe ingress -n kubecost
   kubectl get events -n kubecost
   ```

### Log Analysis
```bash
# Get cost-analyzer logs
kubectl logs -n kubecost deployment/kubecost-cost-analyzer

# Get Prometheus logs (if using built-in)
kubectl logs -n kubecost deployment/kubecost-prometheus-server
```

## Security Considerations

1. **RBAC**: Minimal required permissions for cluster resource read access
2. **Network Policies**: Restricts network traffic to necessary communications
3. **Service Account**: Dedicated service account with limited privileges
4. **TLS**: HTTPS access via ingress with cert-manager integration

## Backup and Disaster Recovery

### Persistent Data
Kubecost stores data in persistent volumes. Ensure your cluster has:
- Regular PV backups configured
- Storage class with appropriate redundancy
- Disaster recovery procedures for persistent data

### Configuration Backup
All configuration is stored in Git, providing:
- Version control for all changes
- Easy rollback capabilities
- Disaster recovery through GitOps

## Troubleshooting

### Common Issues

#### 1. "app path does not exist" Error
If you get the error: `application spec for platform-tools is invalid: InvalidSpecError: Unable to generate manifests in kubecost: rpc error: code = Unknown desc = kubecost: app path does not exist`

**Solution**: Use the direct Helm chart approach instead:
```bash
kubectl apply -f platform-tools/kubecost/base/application-helm-direct.yaml
```

This bypasses path resolution issues by using the Helm chart directly from the repository.

#### 2. Namespace Already Exists
If the kubecost namespace already exists, remove the `CreateNamespace=true` syncOption from the application manifest.

#### 3. Storage Class Issues
Update the `persistentVolume.storageClass` parameter in the Helm values to match your cluster's available storage classes:
```bash
kubectl get storageclass
```

#### 4. Ingress Configuration
Update the ingress host and TLS settings in the application values to match your domain and certificate setup.

### Validation Steps

After deployment, verify the installation:

```bash
# Check ArgoCD application status
kubectl get application kubecost -n argocd

# Check pod status in kubecost namespace
kubectl get pods -n kubecost

# Check service accessibility
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090

# Access Kubecost UI at http://localhost:9090
```

## Support and Documentation

- **Official Kubecost Documentation**: https://docs.kubecost.com/
- **Helm Chart Repository**: https://kubecost.github.io/cost-analyzer/
- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **Kustomize Documentation**: https://kustomize.io/

## License

This deployment configuration is provided under the same license as the Kubecost project. See the official Kubecost repository for license details.

---

**Note**: Remember to update domain names, storage classes, and other environment-specific values before deployment.