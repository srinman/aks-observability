# AKS Observability Quick Reference

## Environment Variables (Run First!)

```bash
# Set your cluster details
export CLUSTER_NAME="<your-aks-cluster-name>"
export CLUSTER_RG="<your-aks-resource-group>"

# Get pre-created monitoring resource IDs
export LAW_RESOURCE_ID=$(az monitor log-analytics workspace show --resource-group infrarg --name aksresourcelogs --query id -o tsv)
export AMW_RESOURCE_ID=$(az monitor account show --resource-group infrarg --name amwforaks --query id -o tsv)
export AMG_RESOURCE_ID=$(az grafana show --resource-group infrarg --name amgforaks --query id -o tsv)
export CLUSTER_RESOURCE_ID=$(az aks show --resource-group $CLUSTER_RG --name $CLUSTER_NAME --query id -o tsv)
```

---

## Quick Setup Commands

### For New Cluster

```bash
# All-in-one: Create cluster with full observability
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

# Enable diagnostic settings
az monitor diagnostic-settings create \
  --name "aks-control-plane-logs" \
  --resource $CLUSTER_RESOURCE_ID \
  --workspace $LAW_RESOURCE_ID \
  --logs '[{"category": "kube-apiserver", "enabled": true}, {"category": "kube-audit", "enabled": true}]'
```

### For Existing Cluster

```bash
# Enable Container Insights (logs)
az aks enable-addons --addon monitoring --name $CLUSTER_NAME --resource-group $CLUSTER_RG --workspace-resource-id $LAW_RESOURCE_ID

# Enable Azure Monitor metrics (Prometheus)
az aks update --resource-group $CLUSTER_RG --name $CLUSTER_NAME --enable-azure-monitor-metrics --azure-monitor-workspace-resource-id $AMW_RESOURCE_ID --grafana-resource-id $AMG_RESOURCE_ID

# Enable diagnostic settings
az monitor diagnostic-settings create --name "aks-control-plane-logs" --resource $CLUSTER_RESOURCE_ID --workspace $LAW_RESOURCE_ID --logs '[{"category": "kube-apiserver", "enabled": true}]'
```

---

## Component Verification

```bash
# Container Insights (Logs)
kubectl get pods -n kube-system | grep ama-logs

# Azure Monitor Metrics (Prometheus)
kubectl get pods -n kube-system | grep ama-metrics

# Diagnostic Settings
az monitor diagnostic-settings list --resource $CLUSTER_RESOURCE_ID --query "value[].name" -o tsv

# Grafana URL
az grafana show --resource-group infrarg --name amgforaks --query properties.endpoint -o tsv
```

---

## Resource Mapping

| Component | Resource Name | Resource Group | Purpose |
|-----------|--------------|----------------|---------|
| Log Analytics Workspace | `aksresourcelogs` | `infrarg` | Container logs, control plane logs, syslog |
| Azure Monitor Workspace | `amwforaks` | `infrarg` | Prometheus metrics |
| Azure Managed Grafana | `amgforaks` | `infrarg` | Dashboards and visualization |

---

## What Gets Collected

| Data Type | Source | Destination | Enable Method |
|-----------|--------|-------------|---------------|
| **Container Logs** | Pod stdout/stderr | LAW: `aksresourcelogs` | `--enable-addons monitoring` |
| **Control Plane Logs** | API server, scheduler, etc. | LAW: `aksresourcelogs` | `az monitor diagnostic-settings create` |
| **Syslog** | Worker nodes | LAW: `aksresourcelogs` | `--data-collection-settings` |
| **Prometheus Metrics** | Kube State Metrics, pods | AMW: `amwforaks` | `--enable-azure-monitor-metrics` |
| **Platform Metrics** | AKS cluster metrics | Azure Monitor | Automatic |

---

## Common KQL Queries

```kusto
// Container logs
ContainerLogV2
| where TimeGenerated > ago(1h)
| project TimeGenerated, PodName, LogMessage

// Control plane logs
AKSControlPlane
| where Category == "kube-apiserver"
| where TimeGenerated > ago(1h)

// Audit logs
AKSAudit
| where TimeGenerated > ago(1h)
| project TimeGenerated, verb_s, requestURI_s, user_username_s
```

---

## Common Prometheus Queries

```promql
# Pod count by namespace
count by (namespace) (kube_pod_info)

# Pod status
kube_pod_status_phase

# Deployment replicas
kube_deployment_status_replicas

# Node status
kube_node_status_condition
```

---

## Disable Container Insights Metrics (To Avoid Duplication)

```bash
cat <<EOF | kubectl apply -f -
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
```

---

## Troubleshooting

```bash
# Check addon status
az aks show --resource-group $CLUSTER_RG --name $CLUSTER_NAME --query "addonProfiles.omsagent" -o json

# Check metrics addon
az aks show --resource-group $CLUSTER_RG --name $CLUSTER_NAME --query "azureMonitorProfile" -o json

# View pod logs
kubectl logs -n kube-system <pod-name>

# Describe pod
kubectl describe pod -n kube-system <pod-name>
```

---

## Complete Setup Verification Script

```bash
#!/bin/bash
echo "=== AKS Observability Status ==="
echo ""
echo "Cluster: $CLUSTER_NAME in $CLUSTER_RG"
echo ""
echo "1. Container Insights (Logs):"
kubectl get pods -n kube-system | grep ama-logs
echo ""
echo "2. Azure Monitor Metrics (Prometheus):"
kubectl get pods -n kube-system | grep ama-metrics
echo ""
echo "3. Diagnostic Settings:"
az monitor diagnostic-settings list --resource $CLUSTER_RESOURCE_ID --query "value[].name" -o tsv
echo ""
echo "4. Grafana URL:"
az grafana show --resource-group infrarg --name amgforaks --query properties.endpoint -o tsv
echo ""
echo "✅ Setup Complete!"
```

Save as `verify-observability.sh` and run: `bash verify-observability.sh`
