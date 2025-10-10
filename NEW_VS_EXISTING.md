# New vs Existing Cluster Setup Comparison

## Quick Comparison

| Aspect | New Cluster | Existing Cluster |
|--------|-------------|------------------|
| **Commands** | Single `az aks create` + diagnostic settings | Multiple `az aks enable-addons` + `az aks update` + diagnostic settings |
| **Time to Complete** | ~10-15 minutes | ~5-10 minutes |
| **Downtime** | N/A (new cluster) | Minimal (pods restart) |
| **Prerequisites** | Resource names available | Cluster must exist and be accessible |
| **Risk** | Low (fresh start) | Low (additive changes only) |

---

## Side-by-Side Commands

### Environment Setup (Same for Both)

```bash
export CLUSTER_NAME="<your-cluster>"
export CLUSTER_RG="<your-rg>"
export LAW_RESOURCE_ID=$(az monitor log-analytics workspace show --resource-group infrarg --name aksresourcelogs --query id -o tsv)
export AMW_RESOURCE_ID=$(az monitor account show --resource-group infrarg --name amwforaks --query id -o tsv)
export AMG_RESOURCE_ID=$(az grafana show --resource-group infrarg --name amgforaks --query id -o tsv)
```

---

## Step-by-Step Comparison

### Step 1: Create/Update Cluster

#### New Cluster
```bash
# Single command creates cluster with monitoring
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
```

**What happens:**
- ✅ Creates AKS cluster
- ✅ Enables Container Insights
- ✅ Enables Prometheus metrics
- ✅ Links Grafana
- ⏱️ Takes ~10-15 minutes

#### Existing Cluster
```bash
# Step 1a: Enable Container Insights
az aks enable-addons \
  --addon monitoring \
  --name $CLUSTER_NAME \
  --resource-group $CLUSTER_RG \
  --workspace-resource-id $LAW_RESOURCE_ID

# Step 1b: Enable Prometheus metrics
az aks update \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --enable-azure-monitor-metrics \
  --azure-monitor-workspace-resource-id $AMW_RESOURCE_ID \
  --grafana-resource-id $AMG_RESOURCE_ID
```

**What happens:**
- ✅ Adds monitoring to existing cluster
- ✅ Deploys ama-logs pods
- ✅ Deploys ama-metrics pods
- ⏱️ Takes ~5-10 minutes per command

---

### Step 2: Get Cluster Credentials (New Cluster Only)

#### New Cluster
```bash
# Required after cluster creation
az aks get-credentials \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --overwrite-existing
```

#### Existing Cluster
```bash
# Not needed - already have credentials
# (But can run if credentials need refresh)
```

---

### Step 3: Get Cluster Resource ID

#### Both (Same Command)
```bash
export CLUSTER_RESOURCE_ID=$(az aks show \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --query id -o tsv)
```

---

### Step 4: Enable Diagnostic Settings

#### Both (Same Command)
```bash
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
  ]'
```

**What happens:**
- ✅ Enables control plane logging
- ✅ Sends logs to LAW
- ⏱️ Takes ~30 seconds

---

### Step 5: Disable Container Insights Metrics

#### Both (Same Command)
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

**What happens:**
- ✅ Prevents duplicate metrics
- ✅ Container Insights only does logs
- ⏱️ Instant

---

## Complete Scripts

### New Cluster - Complete Script

```bash
#!/bin/bash
set -e

# Environment setup
export CLUSTER_NAME="my-aks-cluster"
export CLUSTER_RG="my-resource-group"
export LAW_RESOURCE_ID=$(az monitor log-analytics workspace show --resource-group infrarg --name aksresourcelogs --query id -o tsv)
export AMW_RESOURCE_ID=$(az monitor account show --resource-group infrarg --name amwforaks --query id -o tsv)
export AMG_RESOURCE_ID=$(az grafana show --resource-group infrarg --name amgforaks --query id -o tsv)

# Create cluster with full monitoring
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

# Get credentials
az aks get-credentials --resource-group $CLUSTER_RG --name $CLUSTER_NAME --overwrite-existing

# Get cluster ID
export CLUSTER_RESOURCE_ID=$(az aks show --resource-group $CLUSTER_RG --name $CLUSTER_NAME --query id -o tsv)

# Enable diagnostic settings
az monitor diagnostic-settings create \
  --name "aks-control-plane-logs" \
  --resource $CLUSTER_RESOURCE_ID \
  --workspace $LAW_RESOURCE_ID \
  --logs '[{"category": "kube-apiserver", "enabled": true}, {"category": "kube-audit", "enabled": true}]'

# Disable duplicate metrics
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
        monitor_kubernetes_pods = false
EOF

echo "✅ New cluster setup complete!"
```

### Existing Cluster - Complete Script

```bash
#!/bin/bash
set -e

# Environment setup
export CLUSTER_NAME="my-existing-cluster"
export CLUSTER_RG="my-resource-group"
export LAW_RESOURCE_ID=$(az monitor log-analytics workspace show --resource-group infrarg --name aksresourcelogs --query id -o tsv)
export AMW_RESOURCE_ID=$(az monitor account show --resource-group infrarg --name amwforaks --query id -o tsv)
export AMG_RESOURCE_ID=$(az grafana show --resource-group infrarg --name amgforaks --query id -o tsv)

# Enable Container Insights
az aks enable-addons \
  --addon monitoring \
  --name $CLUSTER_NAME \
  --resource-group $CLUSTER_RG \
  --workspace-resource-id $LAW_RESOURCE_ID

# Enable Azure Monitor metrics
az aks update \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --enable-azure-monitor-metrics \
  --azure-monitor-workspace-resource-id $AMW_RESOURCE_ID \
  --grafana-resource-id $AMG_RESOURCE_ID

# Get cluster ID
export CLUSTER_RESOURCE_ID=$(az aks show --resource-group $CLUSTER_RG --name $CLUSTER_NAME --query id -o tsv)

# Enable diagnostic settings
az monitor diagnostic-settings create \
  --name "aks-control-plane-logs" \
  --resource $CLUSTER_RESOURCE_ID \
  --workspace $LAW_RESOURCE_ID \
  --logs '[{"category": "kube-apiserver", "enabled": true}, {"category": "kube-audit", "enabled": true}]'

# Disable duplicate metrics
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
        monitor_kubernetes_pods = false
EOF

echo "✅ Existing cluster updated!"
```

---

## Feature Comparison Matrix

| Feature | New Cluster | Existing Cluster | Command |
|---------|-------------|------------------|---------|
| **Container Insights** | Enabled during creation | Added via enable-addons | `--enable-addons monitoring` |
| **Prometheus Metrics** | Enabled during creation | Added via update | `--enable-azure-monitor-metrics` |
| **Grafana Link** | Linked during creation | Linked via update | `--grafana-resource-id` |
| **Control Plane Logs** | Requires separate command | Requires separate command | `az monitor diagnostic-settings` |
| **Node Count** | Specified at creation | Cannot change via monitoring commands | `--node-count` |
| **Identity Type** | Specified at creation | Cannot change via monitoring commands | `--enable-managed-identity` |

---

## Timeline Comparison

### New Cluster Timeline

```
0:00  ├─ Start: az aks create
      │
0:10  ├─ Cluster created
      ├─ Container Insights deployed
      ├─ Prometheus metrics deployed
      │
0:11  ├─ Get credentials
      │
0:12  ├─ Enable diagnostic settings
      │
0:13  ├─ Disable duplicate metrics
      │
0:15  └─ Complete ✅

Total: ~15 minutes
```

### Existing Cluster Timeline

```
0:00  ├─ Start: az aks enable-addons
      │
0:05  ├─ Container Insights deployed
      │
      ├─ Start: az aks update
      │
0:10  ├─ Prometheus metrics deployed
      │
0:11  ├─ Enable diagnostic settings
      │
0:12  ├─ Disable duplicate metrics
      │
0:13  └─ Complete ✅

Total: ~13 minutes
```

---

## When to Use Each Approach

### Use New Cluster Approach When:
- ✅ Starting fresh project
- ✅ Want monitoring from day one
- ✅ No existing workloads to migrate
- ✅ Can wait for full cluster creation
- ✅ Want simplest command sequence

### Use Existing Cluster Approach When:
- ✅ Already have running cluster
- ✅ Workloads are already deployed
- ✅ Want to add monitoring to production
- ✅ Need to minimize changes
- ✅ Want granular control over each step

---

## Common Pitfalls

### New Cluster
| Issue | Cause | Solution |
|-------|-------|----------|
| Cluster name exists | Name collision | Choose unique name |
| Missing --generate-ssh-keys | No SSH key specified | Add flag or provide SSH key |
| Wrong region | Resources in different regions | Verify resource locations |

### Existing Cluster
| Issue | Cause | Solution |
|-------|-------|----------|
| Addon already enabled | Running enable-addons twice | Check addon status first |
| Update fails | Cluster in failed state | Fix cluster issues first |
| ConfigMap not applying | kubectl not configured | Run `az aks get-credentials` |

---

## Verification (Same for Both)

```bash
# 1. Check pods
kubectl get pods -n kube-system | grep -E "(ama-logs|ama-metrics)"

# 2. Verify monitoring addon
az aks show --resource-group $CLUSTER_RG --name $CLUSTER_NAME --query "addonProfiles.omsagent.enabled"

# 3. Verify metrics profile
az aks show --resource-group $CLUSTER_RG --name $CLUSTER_NAME --query "azureMonitorProfile.metrics.enabled"

# 4. Check diagnostic settings
az monitor diagnostic-settings list --resource $CLUSTER_RESOURCE_ID --query "value[].name"

# 5. Get Grafana URL
az grafana show --resource-group infrarg --name amgforaks --query properties.endpoint -o tsv
```

---

## Summary

**New Cluster:**
- ➕ Single command for most setup
- ➕ Cleaner, from-scratch approach
- ➖ Longer total time (cluster creation + monitoring)
- ✅ Best for: New projects

**Existing Cluster:**
- ➕ Faster (no cluster creation)
- ➕ Minimal disruption to running workloads
- ➖ More commands to run
- ✅ Best for: Adding monitoring to production

Both approaches result in **identical monitoring capabilities**!
