#!/bin/bash

# Kubecost Deployment and Fix Script
# This script will help fix the current deployment issues

echo "🔧 Kubecost Deployment Fix Script"
echo "=================================="

# Set namespace
NAMESPACE="kubecost"

echo "📊 Current Pod Status:"
kubectl get pods -n $NAMESPACE

echo ""
echo "🔍 Checking problematic pods..."

# Check pending cost-analyzer pod
echo ""
echo "📋 Cost Analyzer Pod Details:"
kubectl describe pod -n $NAMESPACE $(kubectl get pods -n $NAMESPACE | grep cost-analyzer | grep Pending | awk '{print $1}') | tail -20

# Check crashing cluster-controller
echo ""
echo "💥 Cluster Controller Logs:"
kubectl logs -n $NAMESPACE $(kubectl get pods -n $NAMESPACE | grep cluster-controller | awk '{print $1}') --previous --tail=20

echo ""
echo "🔧 Applying fixes..."

# Option 1: Use minimal configuration
echo "Would you like to apply minimal resource configuration? (y/n)"
read -r apply_minimal

if [ "$apply_minimal" = "y" ] || [ "$apply_minimal" = "Y" ]; then
    echo "Applying minimal configuration..."
    kubectl apply -k overlays/minimal/
else
    # Option 2: Restart with updated base configuration
    echo "Restarting with updated base configuration..."
    kubectl apply -k .
fi

echo ""
echo "⏳ Waiting for pods to restart..."
kubectl rollout restart deployment/kubecost-cost-analyzer -n $NAMESPACE
kubectl rollout restart deployment/kubecost-cluster-controller -n $NAMESPACE

echo "Waiting for rollout to complete..."
kubectl rollout status deployment/kubecost-cost-analyzer -n $NAMESPACE --timeout=300s
kubectl rollout status deployment/kubecost-cluster-controller -n $NAMESPACE --timeout=300s

echo ""
echo "📊 Updated Pod Status:"
kubectl get pods -n $NAMESPACE

echo ""
echo "🔍 Checking for remaining issues..."

# Check if any pods are still problematic
PENDING_PODS=$(kubectl get pods -n $NAMESPACE | grep Pending | wc -l)
CRASHLOOP_PODS=$(kubectl get pods -n $NAMESPACE | grep CrashLoopBackOff | wc -l)
ERROR_PODS=$(kubectl get pods -n $NAMESPACE | grep Error | wc -l)

if [ "$PENDING_PODS" -gt 0 ]; then
    echo "⚠️  Still have $PENDING_PODS pending pods"
    echo "Running resource diagnostics..."
    kubectl top nodes
    echo ""
    echo "Check if nodes have sufficient resources:"
    kubectl describe nodes | grep -A 5 "Allocated resources"
fi

if [ "$CRASHLOOP_PODS" -gt 0 ] || [ "$ERROR_PODS" -gt 0 ]; then
    echo "⚠️  Still have $((CRASHLOOP_PODS + ERROR_PODS)) problematic pods"
    echo "Getting recent logs..."
    kubectl logs -n $NAMESPACE deployment/kubecost-cluster-controller --tail=10
fi

echo ""
echo "🚀 Testing port-forward..."
echo "Attempting to port-forward to cost-analyzer service..."
timeout 5s kubectl port-forward -n $NAMESPACE svc/kubecost-cost-analyzer 9090:9090 &
PF_PID=$!
sleep 2
kill $PF_PID 2>/dev/null

RUNNING_PODS=$(kubectl get pods -n $NAMESPACE | grep Running | wc -l)
TOTAL_PODS=$(kubectl get pods -n $NAMESPACE | grep kubecost | wc -l)

echo ""
echo "📈 Summary:"
echo "==========="
echo "Running pods: $RUNNING_PODS/$TOTAL_PODS"
echo "Pending pods: $PENDING_PODS"
echo "Crashing pods: $((CRASHLOOP_PODS + ERROR_PODS))"

if [ "$RUNNING_PODS" -eq "$TOTAL_PODS" ]; then
    echo "✅ All pods are running successfully!"
    echo ""
    echo "🌐 To access Kubecost:"
    echo "kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090"
    echo "Then open: http://localhost:9090"
else
    echo "❌ Some pods are still having issues."
    echo ""
    echo "💡 Troubleshooting steps:"
    echo "1. Check TROUBLESHOOTING.md for detailed diagnostics"
    echo "2. Try the minimal overlay: kubectl apply -k overlays/minimal/"
    echo "3. Check node resources: kubectl top nodes"
    echo "4. Check events: kubectl get events -n kubecost --sort-by='.lastTimestamp'"
fi