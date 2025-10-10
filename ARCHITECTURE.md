# AKS Observability Architecture and Commands

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     AKS Observability Stack                     │
└─────────────────────────────────────────────────────────────────┘

                         Your AKS Cluster
                    ($CLUSTER_NAME in $CLUSTER_RG)
                                │
                                │
        ┌───────────────────────┼───────────────────────┐
        │                       │                       │
        ▼                       ▼                       ▼
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│  Container    │      │   Prometheus  │      │Control Plane  │
│    Logs       │      │    Metrics    │      │     Logs      │
│               │      │               │      │               │
│ stdout/stderr │      │  KSM, cAdvisor│      │ API Server    │
│ Pod logs      │      │  Node metrics │      │ Audit logs    │
└───────┬───────┘      └───────┬───────┘      └───────┬───────┘
        │                      │                      │
        │ ama-logs pods        │ ama-metrics pods     │ Diagnostic
        │                      │                      │ Settings
        ▼                      ▼                      ▼
┌───────────────────────────────────────────────────────────────┐
│                     infrarg Resource Group                    │
├───────────────────┬───────────────────┬───────────────────────┤
│                   │                   │                       │
│  aksresourcelogs  │    amwforaks      │      amgforaks        │
│  (Log Analytics)  │  (Monitor WSP)    │  (Managed Grafana)    │
│                   │                   │                       │
│  📝 Container     │  📊 Prometheus    │  📈 Dashboards        │
│     Logs          │     Metrics       │     Visualization     │
│  🔧 Control       │  📉 Time Series   │  🔍 Query Interface   │
│     Plane Logs    │     Data          │  🚨 Alerting          │
│  📋 Syslog        │                   │                       │
└───────────────────┴───────────────────┴───────────────────────┘
```

---

## Environment Variables Reference

### Required Variables

```bash
# Cluster Configuration
export CLUSTER_NAME="<your-cluster>"      # Your AKS cluster name
export CLUSTER_RG="<your-rg>"             # Your AKS resource group

# Monitoring Resources (Pre-created in infrarg)
export LAW_RESOURCE_ID="<law-id>"         # aksresourcelogs - for logs
export AMW_RESOURCE_ID="<amw-id>"         # amwforaks - for metrics  
export AMG_RESOURCE_ID="<amg-id>"         # amgforaks - for dashboards
export CLUSTER_RESOURCE_ID="<cluster-id>" # Your cluster's ARM ID
```

### Auto-populate Script

```bash
# Run this to set all variables automatically
export CLUSTER_NAME="<your-aks-cluster-name>"
export CLUSTER_RG="<your-aks-resource-group>"
export LAW_RESOURCE_ID=$(az monitor log-analytics workspace show --resource-group infrarg --name aksresourcelogs --query id -o tsv)
export AMW_RESOURCE_ID=$(az monitor account show --resource-group infrarg --name amwforaks --query id -o tsv)
export AMG_RESOURCE_ID=$(az grafana show --resource-group infrarg --name amgforaks --query id -o tsv)
export CLUSTER_RESOURCE_ID=$(az aks show --resource-group $CLUSTER_RG --name $CLUSTER_NAME --query id -o tsv)
```

---

## Command Breakdown: New Cluster

### Single Command (Recommended)

```bash
az aks create \
  --resource-group $CLUSTER_RG \              # Where to create cluster
  --name $CLUSTER_NAME \                      # Cluster name
  --enable-managed-identity \                 # Use managed identity (recommended)
  --node-count 3 \                            # Number of nodes
  --enable-addons monitoring \                # ✅ Enables Container Insights
  --workspace-resource-id $LAW_RESOURCE_ID \  # 📝 Where to send logs
  --enable-azure-monitor-metrics \            # ✅ Enables Prometheus metrics
  --azure-monitor-workspace-resource-id $AMW_RESOURCE_ID \  # 📊 Where to store metrics
  --grafana-resource-id $AMG_RESOURCE_ID \    # 📈 Link Grafana for dashboards
  --generate-ssh-keys                         # Generate SSH keys for nodes
```

**What this does:**
- ✅ Creates AKS cluster
- ✅ Enables Container Insights (logs from pods)
- ✅ Enables Prometheus metrics collection
- ✅ Connects to Grafana for visualization
- ❌ Does NOT enable control plane logs (requires separate command)

### Additional Required Commands

```bash
# 1. Enable control plane logging
az monitor diagnostic-settings create \
  --name "aks-control-plane-logs" \
  --resource $CLUSTER_RESOURCE_ID \           # The cluster to monitor
  --workspace $LAW_RESOURCE_ID \              # Where to send logs
  --logs '[
    {"category": "kube-apiserver", "enabled": true},
    {"category": "kube-audit", "enabled": true},
    {"category": "kube-scheduler", "enabled": true}
  ]'

# 2. Disable duplicate metrics collection
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: container-azm-ms-agentconfig
  namespace: kube-system
data:
  prometheus-data-collection-settings: |-
    [prometheus_data_collection_settings.cluster]
        monitor_kubernetes_pods = false
EOF
```

---

## Command Breakdown: Existing Cluster

### Step 1: Enable Container Insights (Logs)

```bash
az aks enable-addons \
  --addon monitoring \                        # Enable Container Insights
  --name $CLUSTER_NAME \
  --resource-group $CLUSTER_RG \
  --workspace-resource-id $LAW_RESOURCE_ID   # 📝 aksresourcelogs
```

**What this does:**
- ✅ Deploys `ama-logs` DaemonSet (collects logs from all nodes)
- ✅ Deploys `ama-logs-rs` ReplicaSet (aggregates and forwards logs)
- ✅ Sends pod stdout/stderr to Log Analytics Workspace
- ✅ Available tables: `ContainerLogV2`, `KubePodInventory`, `KubeNodeInventory`

### Step 2: Enable Prometheus Metrics

```bash
az aks update \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --enable-azure-monitor-metrics \            # Enable metrics collection
  --azure-monitor-workspace-resource-id $AMW_RESOURCE_ID \  # 📊 amwforaks
  --grafana-resource-id $AMG_RESOURCE_ID      # 📈 amgforaks
```

**What this does:**
- ✅ Deploys `ama-metrics` pods (main collector)
- ✅ Deploys `ama-metrics-ksm` (Kube State Metrics)
- ✅ Deploys `ama-metrics-node` DaemonSet (node metrics)
- ✅ Scrapes Prometheus metrics from kubelet, KSM, cAdvisor
- ✅ Stores in Azure Monitor Workspace
- ✅ Links to Grafana for visualization

### Step 3: Enable Control Plane Logs

```bash
az monitor diagnostic-settings create \
  --name "aks-control-plane-logs" \
  --resource $CLUSTER_RESOURCE_ID \
  --workspace $LAW_RESOURCE_ID \
  --logs '[
    {"category": "kube-apiserver", "enabled": true},
    {"category": "kube-controller-manager", "enabled": true},
    {"category": "kube-scheduler", "enabled": true},
    {"category": "kube-audit", "enabled": true}
  ]'
```

**What this does:**
- ✅ Enables logging for Kubernetes control plane components
- ✅ Available categories: kube-apiserver, kube-audit, kube-scheduler, kube-controller-manager
- ✅ Logs sent to Log Analytics Workspace
- ✅ Available in `AKSControlPlane` and `AKSAudit` tables

---

## What Gets Deployed

### Pods in kube-system Namespace

```bash
# Container Insights (Logs)
NAME                          READY   STATUS    RESTARTS   AGE
ama-logs-xxxxx               3/3     Running   0          5m   # DaemonSet - one per node
ama-logs-rs-yyyyy            2/2     Running   0          5m   # ReplicaSet - aggregator

# Azure Monitor Metrics (Prometheus)
ama-metrics-zzzzz            2/2     Running   0          5m   # Main collector
ama-metrics-ksm-aaaaa        1/1     Running   0          5m   # Kube State Metrics
ama-metrics-node-bbbbb       1/1     Running   0          5m   # DaemonSet - one per node
ama-metrics-operator-ccccc   1/1     Running   0          5m   # Operator
```

### ConfigMaps Created

```bash
# Container Insights configuration
container-azm-ms-agentconfig         # Agent configuration

# Prometheus configuration  
ama-metrics-settings-configmap       # Metrics collection settings
ama-metrics-prometheus-config        # Prometheus scrape config
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      AKS Cluster                                │
│                                                                 │
│  Pod stdout/stderr  ──────────────────────────┐                │
│                                                │                │
│  Node syslog  ─────────────────────────────────┤                │
│                                                │                │
│  kubelet metrics (cAdvisor) ───────┐          │                │
│                                     │          │                │
│  Kube State Metrics ────────────────┤          │                │
│                                     │          │                │
│  Control Plane (API Server, etc.)───┤          │                │
│                                     │          │                │
└─────────────────────────────────────┼──────────┼────────────────┘
                                      │          │
                    ┌─────────────────┘          └──────────────┐
                    │                                           │
                    ▼                                           ▼
        ┌───────────────────────┐                 ┌───────────────────────┐
        │  Azure Monitor        │                 │  Log Analytics        │
        │  Workspace (AMW)      │                 │  Workspace (LAW)      │
        │                       │                 │                       │
        │  amwforaks            │                 │  aksresourcelogs      │
        │                       │                 │                       │
        │  Stores:              │                 │  Stores:              │
        │  - Prometheus metrics │                 │  - Container logs     │
        │  - Time series data   │                 │  - Control plane logs │
        │  - KSM metrics        │                 │  - Audit logs         │
        └───────────┬───────────┘                 │  - Syslog             │
                    │                             └───────────┬───────────┘
                    │                                         │
                    └────────────┐           ┐────────────────┘
                                 │           │
                                 ▼           ▼
                        ┌────────────────────────────┐
                        │  Azure Managed Grafana     │
                        │                            │
                        │  amgforaks                 │
                        │                            │
                        │  - Visual dashboards       │
                        │  - Query both AMW and LAW  │
                        │  - Alerting                │
                        │  - Custom panels           │
                        └────────────────────────────┘
```

---

## Resource Naming Convention

| Purpose | Resource Type | Resource Name | Resource Group | Variable Name |
|---------|--------------|---------------|----------------|---------------|
| Your AKS Cluster | Managed Cluster | `$CLUSTER_NAME` | `$CLUSTER_RG` | `CLUSTER_NAME`, `CLUSTER_RG` |
| Container Logs | Log Analytics | `aksresourcelogs` | `infrarg` | `LAW_RESOURCE_ID` |
| Prometheus Metrics | Monitor Workspace | `amwforaks` | `infrarg` | `AMW_RESOURCE_ID` |
| Dashboards | Managed Grafana | `amgforaks` | `infrarg` | `AMG_RESOURCE_ID` |

---

## Verification Checklist

```bash
# ✅ Check Container Insights
kubectl get pods -n kube-system | grep ama-logs
# Expected: 2+ pods (DaemonSet + ReplicaSet)

# ✅ Check Prometheus Metrics
kubectl get pods -n kube-system | grep ama-metrics
# Expected: 4+ pods (metrics, ksm, node, operator)

# ✅ Check Diagnostic Settings
az monitor diagnostic-settings list --resource $CLUSTER_RESOURCE_ID
# Expected: "aks-control-plane-logs" in output

# ✅ Check Grafana Connection
az grafana show --resource-group infrarg --name amgforaks --query properties.endpoint -o tsv
# Expected: Grafana URL

# ✅ Query Container Logs
# Portal → Log Analytics → Logs → Query: ContainerLogV2 | take 10

# ✅ Query Prometheus Metrics
# Grafana → Explore → Query: kube_pod_info
```

---

## Cost Considerations

| Component | Pricing Model | Typical Cost |
|-----------|--------------|--------------|
| **Log Analytics Workspace** | Per GB ingested + retention | ~$2.30/GB, 31 days free retention |
| **Azure Monitor Workspace** | Per million samples ingested | ~$0.28 per million samples |
| **Azure Managed Grafana** | Per instance | ~$8.40/hour for Standard |
| **AKS Control Plane Logs** | Included in LAW cost | Part of log ingestion |

**Cost Optimization Tips:**
- Use namespace filtering for metrics (`prod-.*` pattern)
- Configure log retention policies
- Disable verbose log categories
- Use sampling for high-volume metrics

---

## Troubleshooting

### Logs Not Appearing

```bash
# Check ama-logs pods status
kubectl get pods -n kube-system -l component=ama-logs

# Check ama-logs configuration
kubectl get configmap container-azm-ms-agentconfig -n kube-system -o yaml

# Check pod logs
kubectl logs -n kube-system -l component=ama-logs --tail=50
```

### Metrics Not Appearing

```bash
# Check ama-metrics pods
kubectl get pods -n kube-system | grep ama-metrics

# Check Prometheus config
kubectl get configmap ama-metrics-prometheus-config -n kube-system -o yaml

# Test Prometheus endpoint
kubectl port-forward -n kube-system svc/ama-metrics 9090:9090
# Access http://localhost:9090
```

### Grafana Not Showing Data

```bash
# Verify Grafana connection
az grafana show --resource-group infrarg --name amgforaks

# Check data sources in Grafana UI
# Grafana → Configuration → Data Sources

# Verify AMW connection
az monitor account show --resource-group infrarg --name amwforaks
```

---

## Next Steps

1. **Access Grafana**: Visit Grafana URL and explore built-in dashboards
2. **Import Dashboards**: Import community dashboards (IDs: 315, 8588, 13332)
3. **Create Alerts**: Set up alerts for critical metrics
4. **Custom Queries**: Learn KQL for log queries and PromQL for metrics
5. **Cost Monitoring**: Monitor ingestion rates and optimize

For detailed information, see the main [README.md](README.md).
