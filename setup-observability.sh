#!/bin/bash

# AKS Observability Complete Setup Script
# This script sets up full observability for a new or existing AKS cluster

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Function to check if command succeeded
check_command() {
    if [ $? -eq 0 ]; then
        print_success "$1"
    else
        print_error "$2"
        exit 1
    fi
}

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     AKS Observability Complete Setup Script               ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Prompt for cluster details
read -p "Enter AKS cluster name: " CLUSTER_NAME
read -p "Enter AKS resource group: " CLUSTER_RG
read -p "Is this a new cluster? (yes/no): " IS_NEW_CLUSTER

export CLUSTER_NAME
export CLUSTER_RG

print_info "Setting up observability for cluster: $CLUSTER_NAME in $CLUSTER_RG"
echo ""

# Step 2: Get monitoring resource IDs
print_info "Retrieving monitoring resource IDs..."

export LAW_RESOURCE_ID=$(az monitor log-analytics workspace show \
  --resource-group infrarg \
  --name aksresourcelogs \
  --query id -o tsv 2>/dev/null)
check_command "Log Analytics Workspace ID retrieved" "Failed to get Log Analytics Workspace ID"

export AMW_RESOURCE_ID=$(az monitor account show \
  --resource-group infrarg \
  --name amwforaks \
  --query id -o tsv 2>/dev/null)
check_command "Azure Monitor Workspace ID retrieved" "Failed to get Azure Monitor Workspace ID"

export AMG_RESOURCE_ID=$(az grafana show \
  --resource-group infrarg \
  --name amgforaks \
  --query id -o tsv 2>/dev/null)
check_command "Azure Managed Grafana ID retrieved" "Failed to get Azure Managed Grafana ID"

echo ""
print_success "All monitoring resources found!"
echo "  📝 LAW: aksresourcelogs"
echo "  📊 AMW: amwforaks"
echo "  📈 AMG: amgforaks"
echo ""

# Step 3: Create or update cluster
if [[ "$IS_NEW_CLUSTER" == "yes" || "$IS_NEW_CLUSTER" == "y" ]]; then
    print_info "Creating new AKS cluster with full observability..."
    
    az aks create \
      --resource-group $CLUSTER_RG \
      --name $CLUSTER_NAME \
      --enable-managed-identity \
      --node-count 3 \
      --enable-addons monitoring \
      --workspace-resource-id $LAW_RESOURCE_ID \
      --enable-azure-monitor-metrics \
      --azure-monitor-workspace-resource-id $AMW_RESOURCE_ID \
      --grafana-resource-id $AMG_RESOURCE_ID \
      --generate-ssh-keys
    
    check_command "AKS cluster created successfully" "Failed to create AKS cluster"
    
    print_info "Getting cluster credentials..."
    az aks get-credentials \
      --resource-group $CLUSTER_RG \
      --name $CLUSTER_NAME \
      --overwrite-existing
    check_command "Cluster credentials retrieved" "Failed to get cluster credentials"
    
else
    print_info "Updating existing AKS cluster with observability..."
    
    # Check if cluster exists
    az aks show --resource-group $CLUSTER_RG --name $CLUSTER_NAME > /dev/null 2>&1
    check_command "Cluster found" "Cluster $CLUSTER_NAME not found in resource group $CLUSTER_RG"
    
    print_info "Enabling Container Insights..."
    az aks enable-addons \
      --addon monitoring \
      --name $CLUSTER_NAME \
      --resource-group $CLUSTER_RG \
      --workspace-resource-id $LAW_RESOURCE_ID
    check_command "Container Insights enabled" "Failed to enable Container Insights"
    
    print_info "Enabling Azure Monitor metrics..."
    az aks update \
      --resource-group $CLUSTER_RG \
      --name $CLUSTER_NAME \
      --enable-azure-monitor-metrics \
      --azure-monitor-workspace-resource-id $AMW_RESOURCE_ID \
      --grafana-resource-id $AMG_RESOURCE_ID
    check_command "Azure Monitor metrics enabled" "Failed to enable Azure Monitor metrics"
fi

echo ""

# Step 4: Get cluster resource ID
print_info "Getting cluster resource ID..."
export CLUSTER_RESOURCE_ID=$(az aks show \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --query id -o tsv)
check_command "Cluster resource ID retrieved" "Failed to get cluster resource ID"

# Step 5: Enable diagnostic settings
print_info "Enabling control plane diagnostic settings..."

az monitor diagnostic-settings create \
  --name "aks-control-plane-logs" \
  --resource $CLUSTER_RESOURCE_ID \
  --workspace $LAW_RESOURCE_ID \
  --logs '[
    {"category": "kube-apiserver", "enabled": true},
    {"category": "kube-controller-manager", "enabled": true},
    {"category": "kube-scheduler", "enabled": true},
    {"category": "kube-audit", "enabled": true},
    {"category": "cluster-autoscaler", "enabled": true},
    {"category": "cloud-controller-manager", "enabled": true},
    {"category": "guard", "enabled": true}
  ]' 2>/dev/null || print_warning "Diagnostic settings may already exist"

print_success "Diagnostic settings configured"
echo ""

# Step 6: Disable Container Insights metrics to avoid duplication
print_info "Disabling Container Insights metrics collection (to avoid duplication with AMW)..."

cat <<EOF | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: ConfigMap
metadata:
  name: container-azm-ms-agentconfig
  namespace: kube-system
data:
  schema-version: v1
  config-version: ver1
  prometheus-data-collection-settings: |-
    [prometheus_data_collection_settings.cluster]
        interval = "1m"
        monitor_kubernetes_pods = false
    [prometheus_data_collection_settings.node]
        interval = "1m"
EOF

check_command "Container Insights metrics disabled" "Failed to disable Container Insights metrics"
echo ""

# Step 7: Wait for pods to be ready
print_info "Waiting for monitoring pods to be ready (this may take a few minutes)..."
sleep 30

# Step 8: Verify setup
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Verifying Setup                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

print_info "1. Container Insights (Logs):"
kubectl get pods -n kube-system | grep ama-logs || print_warning "AMA logs pods not found yet"
echo ""

print_info "2. Azure Monitor Metrics (Prometheus):"
kubectl get pods -n kube-system | grep ama-metrics || print_warning "AMA metrics pods not found yet"
echo ""

print_info "3. Diagnostic Settings:"
az monitor diagnostic-settings list \
  --resource $CLUSTER_RESOURCE_ID \
  --query "value[].name" -o tsv
echo ""

print_info "4. Grafana Dashboard URL:"
GRAFANA_URL=$(az grafana show \
  --resource-group infrarg \
  --name amgforaks \
  --query properties.endpoint -o tsv)
echo "   $GRAFANA_URL"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Setup Complete!                              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
print_success "Your AKS cluster now has full observability enabled:"
echo ""
echo "  📝 Container Logs (stdout/stderr)"
echo "     → Log Analytics Workspace: aksresourcelogs"
echo ""
echo "  🔧 Control Plane Logs"
echo "     → Log Analytics Workspace: aksresourcelogs"
echo ""
echo "  📊 Prometheus Metrics"
echo "     → Azure Monitor Workspace: amwforaks"
echo ""
echo "  📈 Grafana Dashboards"
echo "     → Azure Managed Grafana: amgforaks"
echo "     → URL: $GRAFANA_URL"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║              Next Steps                                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "1. Access Grafana to view dashboards:"
echo "   $GRAFANA_URL"
echo ""
echo "2. Query logs in Azure Portal:"
echo "   Portal → Log Analytics Workspace → Logs"
echo ""
echo "3. View built-in Kubernetes dashboards in Grafana"
echo ""
echo "4. Import community dashboards (recommended IDs: 315, 8588, 13332)"
echo ""
print_success "Setup completed successfully! 🎉"
