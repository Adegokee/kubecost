# Kubecost Deployment Fix Script (PowerShell)
# This script will help fix the current deployment issues

Write-Host "🔧 Kubecost Deployment Fix Script" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# Set namespace
$NAMESPACE = "kubecost"

Write-Host "📊 Current Pod Status:" -ForegroundColor Yellow
kubectl get pods -n $NAMESPACE

Write-Host ""
Write-Host "🔍 Checking problematic pods..." -ForegroundColor Yellow

# Check pending cost-analyzer pod
Write-Host ""
Write-Host "📋 Cost Analyzer Pod Details:" -ForegroundColor Yellow
$pendingPod = kubectl get pods -n $NAMESPACE | Select-String "cost-analyzer" | Select-String "Pending" | ForEach-Object { ($_ -split '\s+')[0] }
if ($pendingPod) {
    kubectl describe pod -n $NAMESPACE $pendingPod | Select-Object -Last 20
}

# Check crashing cluster-controller
Write-Host ""
Write-Host "💥 Cluster Controller Logs:" -ForegroundColor Red
$controllerPod = kubectl get pods -n $NAMESPACE | Select-String "cluster-controller" | ForEach-Object { ($_ -split '\s+')[0] }
if ($controllerPod) {
    kubectl logs -n $NAMESPACE $controllerPod --previous --tail=20
}

Write-Host ""
Write-Host "🔧 Applying fixes..." -ForegroundColor Green

# Ask user for fix option
$applyMinimal = Read-Host "Would you like to apply minimal resource configuration? (y/n)"

if ($applyMinimal -eq "y" -or $applyMinimal -eq "Y") {
    Write-Host "Applying minimal configuration..." -ForegroundColor Green
    kubectl apply -k overlays/minimal/
} else {
    Write-Host "Restarting with updated base configuration..." -ForegroundColor Green
    kubectl apply -k .
}

Write-Host ""
Write-Host "⏳ Waiting for pods to restart..." -ForegroundColor Yellow
kubectl rollout restart deployment/kubecost-cost-analyzer -n $NAMESPACE
kubectl rollout restart deployment/kubecost-cluster-controller -n $NAMESPACE

Write-Host "Waiting for rollout to complete..." -ForegroundColor Yellow
kubectl rollout status deployment/kubecost-cost-analyzer -n $NAMESPACE --timeout=300s
kubectl rollout status deployment/kubecost-cluster-controller -n $NAMESPACE --timeout=300s

Write-Host ""
Write-Host "📊 Updated Pod Status:" -ForegroundColor Cyan
kubectl get pods -n $NAMESPACE

Write-Host ""
Write-Host "🔍 Checking for remaining issues..." -ForegroundColor Yellow

# Check for problematic pods
$pendingCount = (kubectl get pods -n $NAMESPACE | Select-String "Pending").Count
$crashLoopCount = (kubectl get pods -n $NAMESPACE | Select-String "CrashLoopBackOff").Count  
$errorCount = (kubectl get pods -n $NAMESPACE | Select-String "Error").Count

if ($pendingCount -gt 0) {
    Write-Host "⚠️  Still have $pendingCount pending pods" -ForegroundColor Yellow
    Write-Host "Running resource diagnostics..." -ForegroundColor Yellow
    kubectl top nodes
    Write-Host ""
    Write-Host "Check if nodes have sufficient resources:" -ForegroundColor Yellow
    kubectl describe nodes | Select-String -A 5 "Allocated resources"
}

if ($crashLoopCount -gt 0 -or $errorCount -gt 0) {
    $problemCount = $crashLoopCount + $errorCount
    Write-Host "⚠️  Still have $problemCount problematic pods" -ForegroundColor Yellow
    Write-Host "Getting recent logs..." -ForegroundColor Yellow
    kubectl logs -n $NAMESPACE deployment/kubecost-cluster-controller --tail=10
}

Write-Host ""
Write-Host "🚀 Testing port-forward..." -ForegroundColor Green
Write-Host "Attempting to port-forward to cost-analyzer service..." -ForegroundColor Green

# Test port-forward (will fail if pod not ready, which is expected)
$job = Start-Job -ScriptBlock { kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090 }
Start-Sleep -Seconds 2
Stop-Job $job -PassThru | Remove-Job

$runningCount = (kubectl get pods -n $NAMESPACE | Select-String "Running").Count
$totalCount = (kubectl get pods -n $NAMESPACE | Select-String "kubecost").Count

Write-Host ""
Write-Host "📈 Summary:" -ForegroundColor Cyan
Write-Host "===========" -ForegroundColor Cyan
Write-Host "Running pods: $runningCount/$totalCount" -ForegroundColor White
Write-Host "Pending pods: $pendingCount" -ForegroundColor Yellow
Write-Host "Crashing pods: $($crashLoopCount + $errorCount)" -ForegroundColor Red

if ($runningCount -eq $totalCount) {
    Write-Host "✅ All pods are running successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 To access Kubecost:" -ForegroundColor Cyan
    Write-Host "kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090" -ForegroundColor White
    Write-Host "Then open: http://localhost:9090" -ForegroundColor White
} else {
    Write-Host "❌ Some pods are still having issues." -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Check TROUBLESHOOTING.md for detailed diagnostics" -ForegroundColor White
    Write-Host "2. Try the minimal overlay: kubectl apply -k overlays/minimal/" -ForegroundColor White
    Write-Host "3. Check node resources: kubectl top nodes" -ForegroundColor White
    Write-Host "4. Check events: kubectl get events -n kubecost --sort-by='.lastTimestamp'" -ForegroundColor White
}