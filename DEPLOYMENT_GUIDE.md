# Kubecost Server Deployment Guide

This guide provides step-by-step instructions for deploying Kubecost via ArgoCD on your server infrastructure.

## Pre-Deployment Server Setup

### 1. Kubernetes Cluster Requirements

Ensure your Kubernetes cluster meets the following requirements:

#### Minimum Resources
- **Nodes**: 3+ worker nodes recommended
- **CPU**: 2+ cores per node  
- **Memory**: 4GB+ RAM per node
- **Storage**: 100GB+ available storage
- **Network**: CNI plugin installed (Calico, Flannel, etc.)

#### Kubernetes Version
- **Supported**: 1.21+ (1.24+ recommended)
- **API Server**: Accessible from ArgoCD

### 2. Required Components Installation

#### Install ArgoCD (if not present)
```bash
# Create argocd namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

#### Install Nginx Ingress Controller
```bash
# Install nginx ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml

# Wait for deployment
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

#### Install Cert-Manager
```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager to be ready  
kubectl wait --for=condition=available --timeout=300s deployment/cert-manager -n cert-manager
```

#### Create ClusterIssuer for Let's Encrypt
```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@yourdomain.com  # Replace with your email
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

### 3. Storage Configuration

#### Setup Storage Class (if needed)
```bash
# For local storage (development/testing)
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
EOF

# For cloud providers, use provider-specific storage classes:
# AWS: gp3, gp2
# GCP: pd-ssd, pd-standard  
# Azure: managed-premium, managed-standard
```

## ArgoCD Project Setup

### 1. Create Platform-Tools Project

```bash
# Create ArgoCD project for platform tools
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform-tools
  namespace: argocd
spec:
  description: Platform infrastructure tools and services
  
  # Source repositories
  sourceRepos:
  - 'https://git.edusuc.net/WEBFORX/ArgoCD-gitops'
  - 'https://kubecost.github.io/cost-analyzer/'
  
  # Destination clusters and namespaces
  destinations:
  - namespace: 'kubecost'
    server: https://kubernetes.default.svc
  - namespace: 'argocd'
    server: https://kubernetes.default.svc
    
  # Allowed cluster resources
  clusterResourceWhitelist:
  - group: ''
    kind: Namespace
  - group: 'rbac.authorization.k8s.io'
    kind: ClusterRole
  - group: 'rbac.authorization.k8s.io' 
    kind: ClusterRoleBinding
  - group: 'apiextensions.k8s.io'
    kind: CustomResourceDefinition
  - group: 'networking.k8s.io'
    kind: NetworkPolicy
  - group: 'policy'
    kind: PodSecurityPolicy
    
  # Namespace resource whitelist  
  namespaceResourceWhitelist:
  - group: ''
    kind: ConfigMap
  - group: ''
    kind: Secret
  - group: ''
    kind: Service
  - group: ''
    kind: ServiceAccount
  - group: 'apps'
    kind: Deployment
  - group: 'apps' 
    kind: StatefulSet
  - group: 'networking.k8s.io'
    kind: Ingress
  - group: 'monitoring.coreos.com'
    kind: ServiceMonitor
  - group: 'monitoring.coreos.com'
    kind: PrometheusRule
    
  # RBAC policies
  roles:
  - name: platform-admin
    description: Platform administrators
    policies:
    - p, proj:platform-tools:platform-admin, applications, *, platform-tools/*, allow
    - p, proj:platform-tools:platform-admin, repositories, *, *, allow
    groups:
    - platform-admins
    - devops-team
EOF
```

## Repository Setup and Deployment

### 1. Clone and Configure Repository

```bash
# Clone the ArgoCD GitOps repository
git clone https://git.edusuc.net/WEBFORX/ArgoCD-gitops.git
cd ArgoCD-gitops

# Copy the kubecost configuration from platform-tools
cp -r /path/to/platform-tools/* ./

# Update repository URL in ArgoCD application
sed -i 's|repoURL: .*|repoURL: https://git.edusuc.net/WEBFORX/ArgoCD-gitops|g' argocd-applications/kubecost.yaml
```

### 2. Environment-Specific Configuration

#### Production Configuration
```bash
# Update production domain
sed -i 's|kubecost\.yourdomain\.com|kubecost.production.yourdomain.com|g' \
  platform-tools/kubecost/overlays/production/production-values.yaml

# Update storage classes for production
sed -i 's|storageClass: ""|storageClass: "fast-ssd"|g' \
  platform-tools/kubecost/overlays/production/production-values.yaml
```

#### Staging Configuration  
```bash
# Update staging domain
sed -i 's|kubecost-staging\.yourdomain\.com|kubecost.staging.yourdomain.com|g' \
  platform-tools/kubecost/overlays/staging/staging-values.yaml
```

### 3. Deploy Kubecost Application

```bash
# Commit changes to repository
git add .
git commit -m "Add Kubecost deployment configuration"
git push origin main

# Apply ArgoCD application
kubectl apply -f argocd-applications/kubecost.yaml

# Verify application creation
argocd app list | grep kubecost
```

## DNS and Ingress Configuration

### 1. DNS Setup

Configure DNS records for Kubecost access:

```bash
# Production
kubecost.production.yourdomain.com -> <ingress-controller-ip>

# Staging  
kubecost.staging.yourdomain.com -> <ingress-controller-ip>

# Get ingress controller external IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

### 2. Firewall Configuration

Ensure the following ports are accessible:

```bash
# Ingress Controller
80/tcp   # HTTP (redirects to HTTPS)
443/tcp  # HTTPS

# ArgoCD (for management)
8080/tcp # ArgoCD UI (if using port-forward)

# Kubernetes API (internal)
6443/tcp # Kubernetes API server
```

## Authentication Setup (Optional but Recommended)

### 1. OAuth2-Proxy Setup

```bash
# Install oauth2-proxy for authentication
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  namespace: auth
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oauth2-proxy
  template:
    metadata:
      labels:
        app: oauth2-proxy
    spec:
      containers:
      - name: oauth2-proxy
        image: quay.io/oauth2-proxy/oauth2-proxy:v7.4.0
        args:
        - --provider=github  # or google, azure, etc.
        - --email-domain=*
        - --upstream=file:///dev/null
        - --http-address=0.0.0.0:4180
        - --cookie-secure=true
        - --cookie-secret=CHANGEME32CHARACTERSECRET
        - --client-id=your-oauth-client-id
        - --client-secret=your-oauth-client-secret
        ports:
        - containerPort: 4180
          name: http
---
apiVersion: v1
kind: Service
metadata:
  name: oauth2-proxy
  namespace: auth
spec:
  selector:
    app: oauth2-proxy
  ports:
  - name: http
    port: 4180
    targetPort: 4180
EOF
```

## Deployment Verification

### 1. Check ArgoCD Application Status

```bash
# Check application sync status
argocd app get kubecost

# Sync application if needed
argocd app sync kubecost

# Check application health
argocd app wait kubecost --health
```

### 2. Verify Kubernetes Resources

```bash
# Check namespace creation
kubectl get namespace kubecost

# Check all resources in kubecost namespace
kubectl get all -n kubecost

# Check persistent volume claims
kubectl get pvc -n kubecost

# Check ingress
kubectl get ingress -n kubecost
```

### 3. Verify Pod Status

```bash
# Check pod status
kubectl get pods -n kubecost

# Check logs if pods are not ready
kubectl logs -n kubecost -l app.kubernetes.io/name=cost-analyzer

# Describe pods for events
kubectl describe pods -n kubecost
```

### 4. Test Connectivity

```bash
# Internal connectivity test
kubectl run test-pod --image=curlimages/curl --rm -it -- \
  curl -I kubecost-cost-analyzer.kubecost:9090

# External connectivity test (if ingress is ready)
curl -I https://kubecost.production.yourdomain.com
```

## Monitoring Setup

### 1. Verify Prometheus Integration

```bash
# Check if Prometheus is discovering Kubecost targets
kubectl port-forward -n monitoring svc/prometheus-server 9090:80

# Navigate to http://localhost:9090/targets and look for kubecost targets
```

### 2. Grafana Dashboard Import

```bash
# If using external Grafana, import Kubecost dashboards
# Dashboard IDs from grafana.com:
# - 8576: Kubecost cluster metrics
# - 8739: Kubecost cost analyzer

# Or use the preconfigured dashboard from monitoring.yaml
kubectl apply -f platform-tools/kubecost/overlays/production/monitoring.yaml
```

## Production Checklist

Before going live with Kubecost in production:

### Security Checklist
- [ ] Authentication configured (OAuth2-Proxy or similar)
- [ ] TLS certificates properly configured
- [ ] Network policies applied
- [ ] RBAC permissions reviewed and minimal
- [ ] Secrets stored securely (not in plain text)
- [ ] Pod security contexts configured

### Performance Checklist  
- [ ] Resource limits and requests configured appropriately
- [ ] Storage classes using SSD for production
- [ ] High availability enabled (multiple replicas)
- [ ] Prometheus metrics collection verified
- [ ] Grafana dashboards imported and functional

### Backup Checklist
- [ ] Persistent volume backup strategy in place
- [ ] Database backup procedures documented
- [ ] Recovery testing completed

### Monitoring Checklist
- [ ] AlertManager rules configured
- [ ] Notification channels setup (Slack, email)
- [ ] Runbook created for common issues
- [ ] Performance baselines established

## Troubleshooting Server Issues

### Common Server-Side Problems

#### ArgoCD Sync Issues
```bash
# Check ArgoCD application events
kubectl describe application kubecost -n argocd

# Check ArgoCD controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Force refresh application
argocd app refresh kubecost
```

#### Storage Issues
```bash
# Check available storage
kubectl describe pvc -n kubecost

# Check storage class
kubectl get storageclass

# Check node storage capacity
kubectl describe nodes | grep -A5 "Allocated resources"
```

#### Network Connectivity Issues
```bash
# Check ingress controller status
kubectl get pods -n ingress-nginx

# Check service endpoints
kubectl get endpoints -n kubecost

# Test internal DNS
kubectl run test-dns --image=busybox --rm -it -- nslookup kubecost-cost-analyzer.kubecost.svc.cluster.local
```

#### Resource Constraints
```bash
# Check node resource usage
kubectl top nodes

# Check pod resource usage  
kubectl top pods -n kubecost

# Check for evicted pods
kubectl get pods -n kubecost | grep Evicted

# Check resource quotas
kubectl describe quota -n kubecost
```

## Maintenance Procedures

### Regular Maintenance Tasks

#### Weekly Tasks
```bash
# Check application status
argocd app list --output wide

# Review pod restarts
kubectl get pods -n kubecost -o wide

# Check persistent volume usage
df -h /var/lib/kubelet/pods/*/volumes/kubernetes.io~*/*
```

#### Monthly Tasks  
```bash
# Review and rotate secrets
kubectl get secrets -n kubecost

# Update Kubecost version (test in staging first)
# Clean up old application revisions
argocd app history kubecost --output wide

# Performance review and optimization
kubectl top nodes
kubectl top pods -n kubecost
```

#### Quarterly Tasks
```bash
# Security audit and updates
# Backup verification and restore testing  
# Capacity planning review
# Documentation updates
```

## Support and Escalation

### Internal Support Contacts
- **Platform Team**: platform@webforx.com
- **DevOps Team**: devops@webforx.com  
- **On-Call**: +1-XXX-XXX-XXXX

### External Resources
- **Kubecost Documentation**: https://docs.kubecost.com
- **ArgoCD Documentation**: https://argoproj.github.io/argo-cd/
- **Kubernetes Documentation**: https://kubernetes.io/docs/

### Emergency Procedures
1. **Service Outage**: Follow incident response playbook
2. **Data Loss**: Execute backup recovery procedures
3. **Security Incident**: Contact security team immediately
4. **Performance Degradation**: Scale resources temporarily

---

This completes the server deployment guide for Kubecost via ArgoCD. Follow these procedures in order for a successful production deployment.