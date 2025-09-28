# Kubecost Deployment via ArgoCD

This repository contains the GitOps configuration for deploying Kubecost into Kubernetes clusters using ArgoCD with Kustomize and Helm.

## Overview

Kubecost provides real-time cost visibility and insights for Kubernetes workloads. This deployment setup includes:

- **Cost Monitoring**: Track costs by namespace, deployment, service, and labels
- **Resource Optimization**: Get recommendations for rightsizing and efficiency improvements  
- **Multi-Environment Support**: Separate configurations for staging and production
- **Security**: RBAC, network policies, and authentication integration
- **Monitoring**: Prometheus metrics and Grafana dashboards
- **High Availability**: Production setup with multiple replicas and persistent storage

## Repository Structure

```
platform-tools/
├── kubecost/
│   ├── base/                           # Base Kustomize configuration
│   │   ├── kustomization.yaml          # Base Kustomize with Helm chart
│   │   ├── values.yaml                 # Base Kubecost configuration
│   │   ├── namespace.yaml              # Namespace and network policies
│   │   ├── rbac.yaml                   # Service accounts and RBAC
│   │   └── ingress.yaml                # Ingress configurations
│   └── overlays/
│       ├── production/                 # Production environment
│       │   ├── kustomization.yaml      # Production overrides
│       │   ├── production-values.yaml  # Production-specific values
│       │   └── monitoring.yaml         # Prometheus rules and dashboards
│       └── staging/                    # Staging environment
│           ├── kustomization.yaml      # Staging overrides
│           └── staging-values.yaml     # Staging-specific values
└── argocd-applications/
    └── kubecost.yaml                   # ArgoCD Application manifest
```

## Prerequisites

Before deploying Kubecost, ensure the following components are available in your cluster:

### Required Components
- **ArgoCD** installed and configured
- **Nginx Ingress Controller** for external access
- **Cert-Manager** for TLS certificate management  
- **Prometheus** for metrics collection (or let Kubecost deploy its own)
- **Storage Class** for persistent volumes

### Optional Components
- **OAuth2-Proxy** or similar for authentication
- **Grafana** (Kubecost can deploy its own)
- **External Prometheus** (if not using Kubecost's built-in)

## Quick Start

### 1. Clone Repository
```bash
git clone https://git.edusuc.net/WEBFORX/ArgoCD-gitops.git
cd ArgoCD-gitops
```

### 2. Customize Configuration

Update the following files with your environment-specific settings:

#### Update Domain Names
Edit `platform-tools/kubecost/base/values.yaml`:
```yaml
ingress:
  hosts:
    - host: kubecost.yourdomain.com  # Replace with your domain
```

#### Update Production Overlay  
Edit `platform-tools/kubecost/overlays/production/production-values.yaml`:
```yaml
ingress:
  hosts:
    - host: kubecost.yourdomain.com  # Replace with your domain
```

#### Update ArgoCD Application Repository
Edit `argocd-applications/kubecost.yaml`:
```yaml
spec:
  source:
    repoURL: https://git.edusuc.net/WEBFORX/ArgoCD-gitops  # Your repo URL
```

### 3. Deploy to ArgoCD

Apply the ArgoCD Application:
```bash
kubectl apply -f argocd-applications/kubecost.yaml
```

### 4. Verify Deployment

Check ArgoCD UI or CLI:
```bash
argocd app get kubecost
argocd app sync kubecost
```

Monitor pod status:
```bash
kubectl get pods -n kubecost -w
```

## Configuration Details

### Security Configuration

The deployment includes several security features:

#### RBAC
- Dedicated service account `kubecost-cost-analyzer`
- ClusterRole with minimal required permissions for cost calculation
- Role and RoleBinding for namespace-specific operations
- Pod Security Policy (if enabled in cluster)

#### Network Security
- NetworkPolicy restricting ingress/egress traffic
- Ingress with authentication integration (OAuth2-Proxy)
- TLS termination with cert-manager
- Security headers and rate limiting

#### Pod Security
- Non-root user execution (UID 1001)
- Read-only root filesystem where possible
- Security context with dropped capabilities
- seccomp profile applied

### Storage Configuration

#### Production
- 50GB persistent volume for cost data
- 20GB PostgreSQL storage
- 10GB Grafana storage
- Fast SSD storage class recommended

#### Staging  
- 10GB persistent volume for cost data
- 5GB PostgreSQL storage
- 2GB Grafana storage
- Standard storage class

### Resource Allocation

#### Production Resources
```yaml
kubecostModel:
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "2000m" 
      memory: "4Gi"
```

#### Staging Resources
```yaml
kubecostModel:
  resources:
    requests:
      cpu: "100m"
      memory: "256Mi"
    limits:
      cpu: "500m"
      memory: "1Gi"
```

## Environment-Specific Deployments

### Production Environment

Deploy to production:
```bash
# Update ArgoCD Application to point to production overlay
kubectl patch application kubecost -n argocd --type merge -p '{"spec":{"source":{"path":"platform-tools/kubecost/overlays/production"}}}'
```

Production features:
- High availability with 2 replicas
- Enhanced monitoring and alerting
- Increased resource limits
- Network cost monitoring enabled
- Budget alerts configured

### Staging Environment

Deploy to staging:
```bash
# Update ArgoCD Application to point to staging overlay  
kubectl patch application kubecost -n argocd --type merge -p '{"spec":{"source":{"path":"platform-tools/kubecost/overlays/staging"}}}'
```

Staging features:
- Single replica for cost savings
- Reduced resource allocation
- No SSL/TLS (optional)
- Limited monitoring
- No budget alerts

## Access and Usage

### Accessing Kubecost UI

#### External Access (with authentication)
1. Ensure ingress hostname is configured in DNS
2. Access via: `https://kubecost.yourdomain.com`
3. Authenticate via configured OAuth provider

#### Internal Access (no authentication)
1. Port-forward to service:
   ```bash
   kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090
   ```
2. Access via: `http://localhost:9090`

#### kubectl proxy Access
```bash
kubectl proxy
# Access via: http://localhost:8001/api/v1/namespaces/kubecost/services/kubecost-cost-analyzer:9090/proxy/
```

### Key Features and Usage

#### Cost Allocation Dashboard
- View costs by namespace, deployment, service
- Filter by time range (hourly, daily, monthly)  
- Compare costs across different periods
- Export cost reports

#### Optimization Recommendations
- Navigate to "Savings" tab
- Review rightsizing recommendations
- Identify unused resources
- Cluster efficiency metrics

#### Budget Alerts (Production only)
- Set up budget limits per namespace/team
- Configure Slack/email notifications
- Monitor spending trends

#### API Access
```bash
# Get cost allocation data
curl "http://kubecost.yourdomain.com/model/allocation?window=7d&aggregate=namespace"

# Get cluster costs
curl "http://kubecost.yourdomain.com/model/costDataModel?timeWindow=7d"
```

## Monitoring and Alerting

### Prometheus Metrics

Kubecost exposes metrics on port 9003:
- `kubecost_cluster_costs_total` - Total cluster costs
- `kubecost_namespace_costs` - Per-namespace costs  
- `kubecost_cluster_cpu_efficiency` - CPU efficiency percentage
- `kubecost_cluster_memory_efficiency` - Memory efficiency percentage

### Grafana Dashboards

Pre-configured dashboard includes:
- Total cluster cost trends
- Cost breakdown by namespace
- Resource efficiency metrics
- Cost per CPU/memory hour

### AlertManager Rules

Production deployment includes alerts for:
- High CPU/memory usage (>80%/90%)
- Pod restarts
- Service unavailability  
- High disk usage (>85%)
- Data collection failures

## Cloud Provider Integration

### AWS Integration

For accurate AWS costs, configure:

1. Create IAM role with cost and billing permissions:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow", 
         "Action": [
           "ce:GetRightsizingRecommendation",
           "ce:GetDimensionValues",
           "ce:GetReservationCoverage", 
           "ce:ListCostCategoryDefinitions",
           "ce:GetRightsizingRecommendation",
           "ce:GetCostAndUsage"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

2. Update values.yaml:
   ```yaml
   costAnalyzerConfig:
     awsServiceKeyName: "aws-service-key"
     awsServiceKeySecret: "aws-secret"
   ```

3. Create secret:
   ```bash
   kubectl create secret generic aws-service-key \
     --from-literal=service-key.json='{"access_key":"YOUR_ACCESS_KEY","secret_key":"YOUR_SECRET_KEY"}' \
     -n kubecost
   ```

### Azure Integration

For Azure cost data:

1. Create service principal with billing reader permissions
2. Update values.yaml:
   ```yaml
   costAnalyzerConfig:
     azureSubscriptionID: "your-subscription-id"
     azureServiceKeyName: "azure-service-key" 
     azureServiceKeySecret: "azure-secret"
   ```

### GCP Integration

For Google Cloud cost data:

1. Create service account with billing viewer permissions
2. Download service account key
3. Create secret and update configuration similar to AWS

## Troubleshooting

### Common Issues

#### Pod Stuck in Pending
```bash
# Check events
kubectl describe pod -n kubecost -l app.kubernetes.io/name=cost-analyzer

# Common causes:
# - Insufficient resources
# - Missing storage class  
# - Node selector/taints issues
```

#### Unable to Access UI
```bash
# Check ingress
kubectl get ingress -n kubecost

# Check service
kubectl get svc -n kubecost

# Test internal connectivity
kubectl run test-pod --image=nginx --rm -it -- curl kubecost-cost-analyzer.kubecost:9090
```

#### Missing Cost Data
```bash
# Check Prometheus connectivity  
kubectl logs -n kubecost -l app.kubernetes.io/name=cost-analyzer | grep -i prometheus

# Verify metrics-server is running
kubectl get deployment metrics-server -n kube-system

# Check node-exporter and cadvisor
kubectl get pods -n kube-system | grep -E "(node-exporter|cadvisor)"
```

#### Database Issues
```bash
# Check PostgreSQL status
kubectl get pods -n kubecost -l app.kubernetes.io/name=postgresql

# Check logs
kubectl logs -n kubecost -l app.kubernetes.io/name=postgresql

# Test database connectivity
kubectl run psql-test --image=postgres:13 --rm -it -- psql postgresql://postgres:password@kubecost-postgresql:5432/kubecost
```

### Debug Commands

```bash
# Check all resources
kubectl get all -n kubecost

# Describe main deployment
kubectl describe deployment kubecost-cost-analyzer -n kubecost

# Check persistent volume claims
kubectl get pvc -n kubecost

# View configuration
kubectl get configmap -n kubecost -o yaml

# Check secrets
kubectl get secrets -n kubecost
```

### Log Analysis

```bash
# Cost-analyzer logs
kubectl logs -n kubecost -l app.kubernetes.io/name=cost-analyzer -c cost-analyzer-frontend

# Backend logs  
kubectl logs -n kubecost -l app.kubernetes.io/name=cost-analyzer -c cost-model

# PostgreSQL logs
kubectl logs -n kubecost -l app.kubernetes.io/name=postgresql

# Grafana logs (if enabled)
kubectl logs -n kubecost -l app.kubernetes.io/name=grafana
```

## Maintenance

### Backup and Recovery

#### Backup Cost Data
```bash
# Create backup of PostgreSQL data
kubectl exec -n kubecost kubecost-postgresql-0 -- pg_dump kubecost > kubecost-backup-$(date +%Y%m%d).sql

# Backup persistent volume (if using cloud provider snapshots)
# AWS EBS snapshot
aws ec2 create-snapshot --volume-id vol-xxx --description "Kubecost backup $(date)"

# GCP disk snapshot  
gcloud compute disks snapshot kubecost-pv --snapshot-names kubecost-backup-$(date +%Y%m%d)
```

#### Restore from Backup
```bash
# Restore PostgreSQL data
kubectl exec -i -n kubecost kubecost-postgresql-0 -- psql kubecost < kubecost-backup-20241001.sql
```

### Updates and Upgrades

#### Update Kubecost Version
1. Update image tags in overlays
2. Test in staging environment first  
3. Update production after validation
4. Monitor for any data migration issues

#### Update Helm Chart Version
1. Update version in `base/kustomization.yaml`
2. Review chart changelog for breaking changes
3. Update values if needed for new features
4. Deploy via ArgoCD

### Performance Optimization

#### For Large Clusters (>100 nodes)
```yaml
# Increase resources
kubecostModel:
  resources:
    limits:
      cpu: "4000m"
      memory: "8Gi"

# Enable ETL for better performance
etl: true

# Use external PostgreSQL for production
postgresql:
  enabled: false
  
# Configure external PostgreSQL
costAnalyzerConfig:
  dbConfig:
    enabled: true
    host: "external-postgres.example.com"
    port: 5432
    database: "kubecost"
    username: "kubecost"
    password: "secure-password"
```

## Security Considerations

### Network Security
- Use NetworkPolicies to restrict traffic
- Enable TLS for all external communications  
- Configure ingress authentication
- Restrict access to cost data by RBAC

### Data Privacy
- Kubecost processes cluster metadata, not application data
- Cost data may contain business-sensitive information
- Configure appropriate access controls
- Consider data retention policies

### Secrets Management
- Use Kubernetes secrets for sensitive configuration
- Consider external secret management (Vault, etc.)
- Rotate credentials regularly
- Audit secret access

## Support and Contributing

### Getting Help
- Check Kubecost documentation: https://docs.kubecost.com
- Review GitHub issues: https://github.com/kubecost/cost-analyzer-helm-chart
- Internal team Slack: #platform-tools

### Contributing
1. Create feature branch from main
2. Test changes in staging environment
3. Update documentation  
4. Submit pull request with proper testing evidence
5. Get approval from platform team

### Version History
- v1.0.0 - Initial Kubecost deployment with ArgoCD
- v1.1.0 - Added multi-environment support
- v1.2.0 - Enhanced security and monitoring

---

## License
This configuration is proprietary to WEBFORX. See LICENSE file for details.

## Contact
Platform Team - platform@webforx.com