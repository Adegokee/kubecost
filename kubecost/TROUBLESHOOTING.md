# Kubecost Troubleshooting Guide

## Current Issues Observed

### 1. Pod Status Issues
```bash
kubecost-cost-analyzer-57655b999-nwsbf         0/4     Pending   0                 29h
kubecost-cluster-controller-68698855bd-6w52m   0/1     CrashLoopBackOff   218 (14s ago)     29h
```

## Diagnostic Commands

### Check Pending Pod Details
```bash
# Get detailed pod information
kubectl describe pod -n kubecost kubecost-cost-analyzer-57655b999-nwsbf

# Check events in the namespace
kubectl get events -n kubecost --sort-by='.lastTimestamp'

# Check node resources
kubectl top nodes
kubectl describe nodes
```

### Check CrashLoopBackOff Pod
```bash
# Get logs from the crashing pod
kubectl logs -n kubecost kubecost-cluster-controller-68698855bd-6w52m --previous

# Check current logs
kubectl logs -n kubecost kubecost-cluster-controller-68698855bd-6w52m

# Describe the pod for events
kubectl describe pod -n kubecost kubecost-cluster-controller-68698855bd-6w52m
```

### Check Resource Constraints
```bash
# Check if nodes have sufficient resources
kubectl top nodes
kubectl describe nodes

# Check resource quotas
kubectl get resourcequota -n kubecost
kubectl get limitrange -n kubecost

# Check storage classes
kubectl get storageclass
```

## Common Fixes

### 1. Pending Pod - Likely Causes:
- **Insufficient CPU/Memory**: Node doesn't have enough resources
- **Storage Issues**: PVC can't be provisioned
- **Node Selector Issues**: Pod can't be scheduled on available nodes
- **Taints and Tolerations**: Nodes are tainted and pod lacks tolerations

### 2. CrashLoopBackOff - Likely Causes:
- **Configuration Issues**: Wrong values in configmap/secrets
- **Permission Issues**: RBAC problems
- **Network Issues**: Can't connect to required services
- **Resource Limits**: OOM kills or CPU throttling

## Quick Fix Commands

### Reduce Resource Requirements (if nodes are small)
```bash
# Apply the updated values with reduced resources
kubectl apply -k kubecost/overlays/staging  # Use staging overlay for smaller resources
```

### Check and Fix Storage
```bash
# List available storage classes
kubectl get storageclass

# Check PVC status
kubectl get pvc -n kubecost
kubectl describe pvc -n kubecost
```

### Restart Deployments
```bash
# Restart the cost-analyzer deployment
kubectl rollout restart deployment/kubecost-cost-analyzer -n kubecost

# Restart the cluster-controller
kubectl rollout restart deployment/kubecost-cluster-controller -n kubecost
```

## Emergency Resource Reduction

If your cluster has limited resources, apply these patches:

### Minimal Resource Configuration
```yaml
# Save as kubecost-minimal-patch.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kubecost-cost-analyzer
  namespace: kubecost
spec:
  template:
    spec:
      containers:
      - name: cost-analyzer-frontend
        resources:
          requests:
            cpu: 10m
            memory: 55Mi
          limits:
            cpu: 100m
            memory: 256Mi
      - name: cost-analyzer-server
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 1Gi
      - name: cost-model
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 1Gi
```

Apply with:
```bash
kubectl apply -f kubecost-minimal-patch.yaml
```

## Monitoring Commands

### Check Pod Status
```bash
watch kubectl get pods -n kubecost
```

### Follow Logs
```bash
kubectl logs -f -n kubecost deployment/kubecost-cost-analyzer
kubectl logs -f -n kubecost deployment/kubecost-cluster-controller
```

### Check Services
```bash
kubectl get svc -n kubecost
kubectl get ingress -n kubecost
```