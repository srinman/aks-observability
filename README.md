# AKS Observability Guide

This guide provides comprehensive instructions for implementing observability in Azure Kubernetes Service (AKS) clusters using Azure Monitor, including logs, metrics, and visualization components.

## 🚀 Quick Start Options

**Choose your path:**

1. **Manual Commands**: Follow [Complete Observability Setup](#complete-observability-setup)
2. **Detailed Guide**: Continue reading this document for step-by-step instructions

## 📚 Additional Resources

- **[evolution.md](evolution.md)** - Comprehensive history of logging evolution from bare metal to Kubernetes

## Table of Contents

- [Prerequisites](#prerequisites)
- [Environment Variables Setup](#environment-variables-setup)
- [Complete Observability Setup](#complete-observability-setup)
  - [Verify Complete Setup](#verify-complete-setup)
- [Overview](#overview)
- [Azure Monitor Components](#azure-monitor-components)
- [Monitoring Data Types](#monitoring-data-types)
  - [Activity Logs](#activity-logs)
  - [Platform Metrics](#platform-metrics)
  - [Resource Logs](#resource-logs)
  - [Syslog](#syslog)
  - [Container Insights](#container-insights---logs-from-pod-stdoutstderr)
  - [Azure Monitor Workspace](#azure-monitor-workspace---metrics-from-workloads)
- [Azure Managed Grafana](#azure-managed-grafana)

---

## Prerequisites

The following Azure resources must be created before configuring AKS observability:

- **Log Analytics Workspace**: `aksresourcelogs` in resource group `infrarg`
- **Azure Monitor Workspace**: `amwforaks` in resource group `infrarg`
- **Azure Managed Grafana**: `amgforaks` in resource group `infrarg`

---

## Environment Variables Setup

Set up the following environment variables for your AKS cluster and monitoring resources:

```bash
# AKS Cluster Configuration
export CLUSTER_NAME="aks-cilium"
export CLUSTER_RG="cni-comparison-rg"

# Log Analytics Workspace (for Container Insights logs)
export LAW_RESOURCE_ID=$(az monitor log-analytics workspace show \
  --resource-group infrarg \
  --name aksresourcelogs \
  --query id -o tsv)

# Azure Monitor Workspace (for Prometheus metrics)
export AMW_RESOURCE_ID=$(az monitor account show \
  --resource-group infrarg \
  --name amwforaks \
  --query id -o tsv)

# Azure Managed Grafana (for visualization)
export AMG_RESOURCE_ID=$(az grafana show \
  --resource-group infrarg \
  --name amgforaks \
  --query id -o tsv)

# Verify environment variables
echo "Cluster: $CLUSTER_NAME"
echo "Resource Group: $CLUSTER_RG"
echo "LAW ID: $LAW_RESOURCE_ID"
echo "AMW ID: $AMW_RESOURCE_ID"
echo "AMG ID: $AMG_RESOURCE_ID"
```

---

## Complete Observability Setup

Add complete observability to an existing AKS cluster:

```bash
# Step 1: Enable Container Insights (logs)
az aks enable-addons \
  --addon monitoring \
  --name $CLUSTER_NAME \
  --resource-group $CLUSTER_RG \
  --workspace-resource-id $LAW_RESOURCE_ID

# Step 2: Enable Azure Monitor metrics (Prometheus)
az aks update \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --enable-azure-monitor-metrics \
  --azure-monitor-workspace-resource-id $AMW_RESOURCE_ID 

az aks update \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --grafana-resource-id $AMG_RESOURCE_ID

# Step 3: Get cluster resource ID
CLUSTER_RESOURCE_ID=$(az aks show \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --query id -o tsv)

# Step 4: Enable control plane diagnostic settings
az monitor diagnostic-settings create \
  --name "aks-control-plane-logs" \
  --resource $CLUSTER_RESOURCE_ID \
  --workspace $LAW_RESOURCE_ID \
  --logs '[
    {"category": "kube-apiserver", "enabled": true},
    {"category": "kube-controller-manager", "enabled": true},
    {"category": "kube-scheduler", "enabled": true},
    {"category": "cluster-autoscaler", "enabled": true},
    {"category": "cloud-controller-manager", "enabled": true},
    {"category": "guard", "enabled": true}
  ]'

# Step 5: Disable Container Insights metrics (to avoid duplication with AMW)
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

echo "✅ AKS cluster updated with complete observability stack!"
echo "📊 Grafana URL: $(az grafana show --resource-group infrarg --name amgforaks --query properties.endpoint -o tsv)"
```

### Verify Complete Setup

```bash
# 1. Check Container Insights pods
echo "=== Container Insights (Logs) ==="
kubectl get pods -n kube-system | grep ama-logs



# 2. Check Azure Monitor Metrics pods
echo "=== Azure Monitor Metrics (Prometheus) ==="
kubectl get pods -n kube-system | grep ama-metrics

# 3. Verify diagnostic settings
echo "=== Control Plane Logs ==="
CLUSTER_RESOURCE_ID=$(az aks show \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --query id -o tsv)

az monitor diagnostic-settings list \
  --resource $CLUSTER_RESOURCE_ID \
  --query "value[].name" -o tsv

# 4. Get Grafana URL
echo "=== Grafana Dashboard ==="
az grafana show \
  --resource-group infrarg \
  --name amgforaks \
  --query properties.endpoint -o tsv

echo ""
echo "✅ Setup complete! Your AKS cluster now has:"
echo "  📝 Container logs (stdout/stderr) → aksresourcelogs (LAW)"
echo "  🔧 Control plane logs → aksresourcelogs (LAW)"
echo "  📊 Prometheus metrics → amwforaks (AMW)"
echo "  📈 Grafana dashboards → amgforaks (AMG)"
```

---

## Overview

This document covers the implementation of observability for AKS clusters using Azure's native monitoring services. The solution includes log collection, metric collection, and visualization capabilities.

## Azure Monitor Components

The following Azure resources are required for complete AKS observability:

- **Log Analytics Workspace (LAW)** - Resource to store & view log data 
- **Azure Monitor Workspace (AMW)** - Resource to store and (limited view of) prometheus metrics  
- **Azure Managed Grafana (AMG)** - Resource to build/view dashboards - source can be AMW   

## Monitoring Data Types

---

### Activity Logs

Activity logs provide audit trail information for AKS cluster management operations.

**Documentation:**
- https://learn.microsoft.com/en-us/azure/aks/monitor-aks-reference#activity-log  
- https://learn.microsoft.com/en-us/azure/role-based-access-control/permissions/containers#microsoftcontainerservice  

---

### Platform Metrics

Platform metrics provide performance and health information about the AKS cluster infrastructure.

**Documentation:**
- https://learn.microsoft.com/en-us/azure/aks/monitor-aks-reference#metrics  
- https://learn.microsoft.com/en-us/azure/aks/monitor-aks-reference#supported-metrics-for-microsoftcontainerservicemanagedclusters   

**Baseline Metrics:**
Refer AMBA for baseline metrics to monitor and alert   
https://azure.github.io/azure-monitor-baseline-alerts/services/ContainerService/managedClusters/  

---

### Resource Logs - Logs from Control Plane  

Resource logs capture information from the AKS control plane components.  
Enable with 'Diagnostic Settings'  

**Documentation:**
- https://learn.microsoft.com/en-us/azure/aks/monitor-aks?tabs=cilium#aks-control-plane-resource-logs  
- https://learn.microsoft.com/en-us/azure/aks/monitor-aks?tabs=cilium#sample-log-queries  

#### Enable Diagnostic Settings

```bash
# Get cluster resource ID
CLUSTER_RESOURCE_ID=$(az aks show \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --query id -o tsv)

# Enable diagnostic settings for control plane logs
az monitor diagnostic-settings create \
  --name "aks-control-plane-logs" \
  --resource $CLUSTER_RESOURCE_ID \
  --workspace $LAW_RESOURCE_ID \
  --logs '[
    {
      "category": "kube-apiserver",
      "enabled": true
    },
    {
      "category": "kube-controller-manager",
      "enabled": true
    },
    {
      "category": "kube-scheduler",
      "enabled": true
    },
    {
      "category": "kube-audit",
      "enabled": true
    },
    {
      "category": "cluster-autoscaler",
      "enabled": true
    },
    {
      "category": "cloud-controller-manager",
      "enabled": true
    },
    {
      "category": "guard",
      "enabled": true
    },
    {
      "category": "csi-azuredisk-controller",
      "enabled": true
    },
    {
      "category": "csi-azurefile-controller",
      "enabled": true
    },
    {
      "category": "csi-snapshot-controller",
      "enabled": true
    }
  ]'
```

#### Verify Diagnostic Settings

```bash
# List diagnostic settings
az monitor diagnostic-settings list \
  --resource $CLUSTER_RESOURCE_ID \
  --output table

# Show specific diagnostic setting
az monitor diagnostic-settings show \
  --name "aks-control-plane-logs" \
  --resource $CLUSTER_RESOURCE_ID
```

#### Query Control Plane Logs

```bash
# Portal: Navigate to Log Analytics Workspace → Logs
# Run KQL query:
```

**Sample Query:**
```kusto
AKSControlPlane
| where Category == "kube-apiserver"
| where TimeGenerated > ago(1h)
| project TimeGenerated, Category, log_s
| order by TimeGenerated desc
| take 100
```

**Other useful queries:**
```kusto
// Audit events
AKSAudit
| where TimeGenerated > ago(1h)
| project TimeGenerated, verb_s, requestURI_s, user_username_s
| order by TimeGenerated desc

// Cluster autoscaler logs
AKSControlPlane
| where Category == "cluster-autoscaler"
| where TimeGenerated > ago(1h)
| order by TimeGenerated desc
```

---

### Syslog - Syslog from worker nodes   

Syslog provides system-level logs from worker nodes.

#### Enable Syslog Collection

```bash
# Create data collection settings file
cat <<EOF > dataCollectionSettings.json
{
  "syslog": {
    "facilities": [
      {
        "name": "kern",
        "logLevels": ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
      },
      {
        "name": "user",
        "logLevels": ["Debug", "Info", "Notice", "Warning", "Error", "Critical", "Alert", "Emergency"]
      },
      {
        "name": "daemon",
        "logLevels": ["Warning", "Error", "Critical", "Alert", "Emergency"]
      },
      {
        "name": "syslog",
        "logLevels": ["Warning", "Error", "Critical", "Alert", "Emergency"]
      }
    ]
  }
}
EOF

# Update cluster with syslog collection
az aks update \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --data-collection-settings dataCollectionSettings.json
```

#### Verification

```bash
# Verify AMA agent is collecting syslog
kubectl get pods -n kube-system | grep ama-logs

# Query syslog data in Log Analytics Workspace
# Go to Azure Portal → Log Analytics Workspace → Logs
# Run query:
# Syslog
# | where Computer contains "aks"
# | order by TimeGenerated desc
```

---

### Container Insights - Logs from pod stdout/stderr

Container Insights provides logs from pod stdout/stderr.

> **Important**: Container Insights collect metric data in addition to logs. This must be disabled when AMW is used for metrics collection.

#### Enable Container Insights

```bash
# Enable Container Insights add-on on existing cluster
az aks enable-addons \
  --addon monitoring \
  --name $CLUSTER_NAME \
  --resource-group $CLUSTER_RG \
  --workspace-resource-id $LAW_RESOURCE_ID
```

#### Disable Container Insights Metrics Collection

When using Azure Monitor Workspace (AMW) for Prometheus metrics, disable metrics collection in Container Insights to avoid duplication:

```bash
# Create ConfigMap to disable metrics collection
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: container-azm-ms-agentconfig
  namespace: kube-system
data:
  schema-version: v1
  config-version: ver1
  log-data-collection-settings: |-
    [log_collection_settings]
       [log_collection_settings.stdout]
          enabled = true
       [log_collection_settings.stderr]
          enabled = true
       [log_collection_settings.env_var]
          enabled = true
  prometheus-data-collection-settings: |-
    [prometheus_data_collection_settings.cluster]
        interval = "1m"
        monitor_kubernetes_pods = false
    [prometheus_data_collection_settings.node]
        interval = "1m"
EOF
```

#### Verification Commands

```bash
# Check AMA DaemonSet (one pod per node)
kubectl get ds ama-logs --namespace=kube-system

# Check AMA ReplicaSet deployment
kubectl get deployment ama-logs-rs --namespace=kube-system

# View all monitoring pods
kubectl get pods -n kube-system | grep ama-logs


```

**Reference:** https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable

#### Verify Log Data in Log Analytics Workspace

```bash
# Portal: Navigate to Log Analytics Workspace → Logs
# Query ContainerLogV2 table:
```

**Sample KQL Query:**
```kusto
ContainerLogV2
| where TimeGenerated > ago(1h)
| where PodNamespace in ("default", "kube-system")
| project TimeGenerated, PodName, PodNamespace, LogMessage
| order by TimeGenerated desc
| take 100
```

#### Cluster Status Check

```bash
# Verify monitoring addon status
az aks show \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --query "addonProfiles.omsagent" -o json
```

**Expected Output:**
```json
{
  "config": {
    "logAnalyticsWorkspaceResourceID": "/subscriptions/<subscription-id>/resourceGroups/infrarg/providers/Microsoft.OperationalInsights/workspaces/aksresourcelogs"
  },
  "enabled": true,
  "identity": {
    "clientId": "<client-id>",
    "objectId": "<object-id>",
    "resourceId": "<resource-id>"
  }
}
```

---

### Azure Monitor Workspace - Metrics from workloads 

Azure Monitor Workspace enables metrics collection from workloads using Prometheus.

#### Component Overview

The following components are deployed for metrics collection:

- **ama-metrics pods** - Main metrics collection
- **ama-metrics-ksm pod** - Kube State Metrics
- **ama-metrics-node daemonset pods** (one per node) - Node-level metrics collection
- **ama-metrics-operator-targets pod** - Operator for managing metric targets

#### Enable Azure Monitor Metrics

```bash
# Enable Azure Monitor metrics on existing cluster
az aks update \
  --resource-group $CLUSTER_RG \
  --name $CLUSTER_NAME \
  --enable-azure-monitor-metrics \
  --azure-monitor-workspace-resource-id $AMW_RESOURCE_ID \
  --grafana-resource-id $AMG_RESOURCE_ID
```

#### Verification Commands

```bash
# Check all AMA metrics pods
kubectl get pods -n kube-system | grep -E "(ama-metrics|prometheus)"

# Check pod images
kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image | grep -E "(ama-metrics|prometheus)"

# Expected pods:
# - ama-metrics-* (ReplicaSet - main collection)
# - ama-metrics-ksm-* (Kube State Metrics)
# - ama-metrics-node-* (DaemonSet - one per node)
# - ama-metrics-operator-targets-* (Operator)
```

#### Verify Metrics in Grafana

```bash
# Get Grafana endpoint
az grafana show \
  --resource-group infrarg \
  --name amgforaks \
  --query properties.endpoint -o tsv

# Access Grafana and run test query:
# kube_pod_info
# kube_node_info
# up{job="kubelet"}
```

---

#### Understanding Metrics Collection Methods

Azure Monitor for AKS provides **four different methods** to collect Prometheus metrics. Understanding when to use each is critical for effective monitoring.

##### Collection Methods Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. ConfigMap (ama-metrics-settings-configmap)                  │
│    • Global settings for ALL scraping                           │
│    • Controls: default targets, scrape intervals, namespaces   │
│    • ONE ConfigMap for entire cluster                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ├─ Enables ─→  Pod Annotations
                              ├─ Configures ─→ Default Targets (kubelet, KSM, etc.)
                              └─ Does NOT affect → ServiceMonitors/PodMonitors
                                                    (these work independently)

┌─────────────────────────────────────────────────────────────────┐
│ 2. Pod Annotations (Simplest Application Metrics)              │
│    • Add annotations to Pod spec in Deployment/StatefulSet     │
│    • AMA automatically discovers and scrapes                   │
│    • Must be enabled via ConfigMap namespace regex             │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ 3. ServiceMonitor (Advanced - Service Discovery)               │
│    • Kubernetes Custom Resource (CRD)                          │
│    • Discovers pods via Service labels                        │
│    • Multiple endpoints, relabeling, filtering                │
│    • Works INDEPENDENTLY of ConfigMap settings                │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ 4. PodMonitor (Advanced - Direct Pod Discovery)                │
│    • Kubernetes Custom Resource (CRD)                          │
│    • Discovers pods directly via Pod labels                   │
│    • No Service required                                       │
│    • Works INDEPENDENTLY of ConfigMap settings                │
└─────────────────────────────────────────────────────────────────┘
```

##### When to Use Each Method

| Method | Purpose | When to Use | Configuration Level |
|--------|---------|-------------|-------------------|
| **ConfigMap** | Control default scraping behavior | • Enable/disable default targets (kubelet, KSM)<br>• Set scrape intervals<br>• Enable pod annotation scraping<br>• Control which namespaces are scraped | **Cluster-wide** |
| **Pod Annotations** | Simple application metrics | • Quick setup for apps exposing `/metrics`<br>• No CRD knowledge required<br>• Simple filtering by namespace<br>• **MOST COMMON for custom apps** | **Per-Application** |
| **ServiceMonitor** | Advanced service monitoring | • Need service-level discovery<br>• Multiple endpoints per service<br>• Advanced relabeling<br>• Complex filtering requirements | **Per-Application** |
| **PodMonitor** | Advanced pod monitoring | • Direct pod targeting<br>• No service exists<br>• Different metrics per pod<br>• Maximum control over scraping | **Per-Application** |

##### Azure Best Practices (from Microsoft Documentation)

**Microsoft's Recommended Approach:**

1. **Start with ConfigMap** - Configure cluster-wide defaults
   - Enable necessary default targets (kubelet, KSM, cAdvisor)
   - Set reasonable scrape intervals (default: 30s)
   - Enable pod annotation scraping for specific namespaces

2. **Use Pod Annotations for Most Applications**
   - Simplest method for custom application metrics
   - No need to create additional Kubernetes resources
   - Easy to add to existing Deployments/StatefulSets
   - **Microsoft recommends this for standard use cases**

3. **Use ServiceMonitor/PodMonitor Only When Needed**
   - Advanced filtering/relabeling requirements
   - Multiple scrape endpoints per application
   - Need fine-grained control over metric collection

**Official Guidance:**
- **Pod Annotations**: "Add annotations to the pods in your cluster to scrape application pods without creating a custom Prometheus config"
- **Warning from Microsoft**: "Scraping the pod annotations from many namespaces can generate a very large volume of metrics"
- **CRDs**: Use "to create custom scrape jobs for further customization and additional targets"

##### Practical Decision Tree

```
Do you need to collect metrics from your application?
│
├─ NO → Use ConfigMap to configure default targets only
│       (KSM, kubelet, cAdvisor provide infrastructure metrics)
│
└─ YES → Does your app expose /metrics endpoint?
         │
         ├─ NO → Application changes needed first
         │
         └─ YES → Is simple scraping sufficient?
                  │
                  ├─ YES → Use Pod Annotations
                  │        ✅ Add 3 annotations to Deployment
                  │        ✅ Enable namespace in ConfigMap
                  │        ✅ Done!
                  │
                  └─ NO → Need advanced features?
                          │
                          ├─ Service-level discovery → ServiceMonitor
                          ├─ Direct pod targeting → PodMonitor
                          └─ Multiple endpoints → ServiceMonitor/PodMonitor
```

##### Important Relationships

**ConfigMap vs Pod Annotations:**
- ConfigMap **enables** pod annotation scraping via `podannotationnamespaceregex`
- Without this ConfigMap setting, pod annotations are **ignored**
- ConfigMap controls **which namespaces** are scanned for annotations

**ConfigMap vs ServiceMonitor/PodMonitor:**
- ServiceMonitor and PodMonitor **work independently** of ConfigMap
- ConfigMap settings do **NOT affect** CRD-based scraping
- You can use both simultaneously without conflicts

**ServiceMonitor vs PodMonitor:**
- ServiceMonitor discovers pods **through Services** (uses service labels)
- PodMonitor discovers pods **directly** (uses pod labels)
- ServiceMonitor requires a Kubernetes Service to exist
- PodMonitor does not require a Service

**Reference:** 
- https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration
- https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-crd

---

#### ConfigMap Settings (Cluster-Wide Configuration)

**Purpose:** Configure global settings for default targets and enable pod annotation-based scraping.

**What it controls:**
- Default targets (kubelet, KSM, cAdvisor, etc.)
- Scrape intervals for default targets
- Which namespaces to scan for pod annotations
- Debug mode and cluster alias

**When to use:**
- First step after enabling Azure Monitor metrics
- To control what infrastructure metrics are collected
- To enable pod annotation scraping for specific namespaces

##### Configure pod annotation-based scraping for prod- namespaces:

```bash
cat <<EOF > ama-metrics-settings-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ama-metrics-settings-configmap
  namespace: kube-system
data:
  schema-version:
    v1
  config-version:
    ver1
  default-scrape-settings-enabled: |-
    kubelet = true
    coredns = false
    cadvisor = true
    kubeproxy = false
    apiserver = false
    kubestate = true
    nodeexporter = true
    windowsexporter = false
    windowskubeproxy = false
    kappiebasic = true
    prometheuscollectorhealth = false
  pod-annotation-based-scraping: |-
    podannotationnamespaceregex = "prod-.*"
  debug-mode: |-
    enabled = false
EOF

kubectl apply -f ama-metrics-settings-configmap.yaml
```

##### Pod annotations required for scraping:
```yaml
metadata:   
  annotations:
    prometheus.io/scrape: 'true'
    prometheus.io/path: '/metrics'    # optional, defaults to /metrics
    prometheus.io/port: '8080'        # required - port where metrics are exposed
```

**Reference:** https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration

#### Understanding Metrics Collection Types

##### Default Metrics Collection with Kube State Metrics (KSM)

**KSM** Kube State Metrics (KSM) does NOT require applications to expose Prometheus metrics. 

- **KSM** collects metadata about Kubernetes objects (pods, deployments, services, etc.) from the Kubernetes API server
- **No application modification required** - KSM scrapes the Kubernetes API, not your application endpoints
- **Automatically available** - Deployed as `ama-metrics-ksm` pod when Azure Monitor metrics are enabled

**Example KSM Metrics Available in Grafana:**
- `kube_pod_status_phase` - Pod status (Running, Pending, Failed)
- `kube_deployment_status_replicas` - Number of replicas in deployments
- `kube_node_status_condition` - Node health status
- `kube_service_info` - Service metadata
- `kube_namespace_status_phase` - Namespace status

---

#### Pod Annotation-Based Scraping (Simple Application Metrics)

**Purpose:** Enable automatic scraping of application pods that expose Prometheus metrics using simple pod annotations.

**Prerequisites:**
1. Application must expose metrics at an HTTP endpoint (e.g., `/metrics`)
2. Namespace must be enabled in ConfigMap's `podannotationnamespaceregex` setting

**How it works:**
- Add 3 annotations to your pod template in Deployment/StatefulSet
- AMA-metrics automatically discovers pods with these annotations
- Only pods in namespaces matching the ConfigMap regex are scraped
- No additional Kubernetes resources (CRDs) required

**When to use pod annotations:**
- **Most common method** for custom application metrics
- Spring Boot applications with `/actuator/prometheus`
- Custom applications with `/metrics` endpoints
- Simple, straightforward scraping requirements
- **Microsoft's recommended approach** for standard use cases

#### Practical Example: Namespace-Based Scraping

##### Creating Test Namespaces and Workloads

```bash
# Create namespaces
kubectl create namespace prod-web
kubectl create namespace prod-api
kubectl create namespace dev-test

# Deploy applications with prometheus annotations
cat <<EOF > prod-web-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: prod-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
      annotations:
        prometheus.io/scrape: 'true'
        prometheus.io/path: '/metrics'
        prometheus.io/port: '8080'
    spec:
      containers:
      - name: web-app
        image: nginx:latest
        ports:
        - containerPort: 80
        - containerPort: 8080
          name: metrics
---
apiVersion: v1
kind: Service
metadata:
  name: web-app-service
  namespace: prod-web
  labels:
    app: web-app-service
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
    name: http
  - port: 8080
    targetPort: 8080
    name: metrics
EOF

kubectl apply -f prod-web-app.yaml
```

##### Why Use Namespace Regex `prod-.*`?

```bash
# With podannotationnamespaceregex = "prod-.*"
# ✅ SCRAPED: Pods in prod-web namespace
# ✅ SCRAPED: Pods in prod-api namespace  
# ❌ NOT SCRAPED: Pods in dev-test namespace

kubectl get pods --all-namespaces | grep -E "(prod-|dev-)"
```

**Benefits:**
- **Security**: Only production workloads are monitored
- **Performance**: Reduces metric volume from non-production environments
- **Cost**: Lower ingestion costs by filtering irrelevant metrics
- **Focus**: Production-only dashboards and alerts

#### Advanced Scraping with Custom Resource Definitions (CRDs)

**Purpose:** Provide fine-grained control over metric collection when pod annotations are insufficient.

**Key Characteristics:**
- ServiceMonitor and PodMonitor work **independently** of ConfigMap settings
- Do **NOT require** namespace to be listed in `podannotationnamespaceregex`
- More complex but offer advanced features (relabeling, multiple endpoints, filtering)
- Use Prometheus Operator API specification

**When to use CRDs instead of pod annotations:**
- Need advanced relabeling or filtering
- Multiple scrape endpoints per application
- Different scrape intervals per application
- Complex label manipulation
- Service mesh or multi-service monitoring

**Microsoft Guidance:** "Use custom resource definitions (CRDs) to create custom scrape jobs for further customization and additional targets" (when pod annotations are insufficient)

##### When to Use ServiceMonitor vs PodMonitor

**ServiceMonitor** - Service-based discovery:
- **Discovery method**: Finds pods through Kubernetes Service
- **Requires**: A Service resource must exist
- **Use when**: You have a Service exposing your application
- **Advantage**: Service-level abstraction, load balancing awareness
- **Common scenarios**: Production applications with Services, microservices

**PodMonitor** - Direct pod discovery:
- **Discovery method**: Finds pods directly by pod labels
- **Requires**: No Service needed
- **Use when**: No Service exists or you need pod-specific metrics
- **Advantage**: Direct pod access, more granular control
- **Common scenarios**: DaemonSets, StatefulSets, testing environments
```yaml
apiVersion: azmonitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: web-app-monitor
  namespace: prod-web
spec:
  selector:
    matchLabels:
      app: web-app-service
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
```

**PodMonitor** - Use for direct pod scraping without services:
```yaml
apiVersion: azmonitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: pod-monitor
  namespace: prod-api
spec:
  selector:
    matchLabels:
      app: api-app
  podMetricsEndpoints:
  - port: metrics
    path: /actuator/prometheus
    interval: 15s
```

##### Comparison Table

| Feature | Pod Annotations | ServiceMonitor | PodMonitor |
|---------|----------------|----------------|------------|
| **Configuration Type** | Annotations in Pod spec | Kubernetes CRD | Kubernetes CRD |
| **Complexity** | ⭐ Simple | ⭐⭐⭐ Advanced | ⭐⭐⭐ Advanced |
| **Requires ConfigMap** | ✅ Yes (namespace regex) | ❌ No (independent) | ❌ No (independent) |
| **Requires Service** | ❌ No | ✅ Yes | ❌ No |
| **Discovery Method** | Pod annotations | Service labels | Pod labels |
| **Scrape Interval** | Fixed (from ConfigMap) | Per-monitor customizable | Per-monitor customizable |
| **Relabeling Support** | ❌ No | ✅ Yes (advanced) | ✅ Yes (advanced) |
| **Multiple Endpoints** | ❌ No (single port) | ✅ Yes | ✅ Yes |
| **Namespace Filtering** | Via ConfigMap regex | Via CRD selector | Via CRD selector |
| **Microsoft Recommendation** | ✅ **Start here** | Use when needed | Use when needed |

**Decision Guide:**
- **Use Pod Annotations**: For 80% of custom application metrics (simple, quick, sufficient)
- **Use ServiceMonitor**: When you need service-level discovery and advanced features
- **Use PodMonitor**: When you need direct pod targeting without Services

**Reference:** https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-crd

---

#### Complete Example: Same Application, Three Methods

Let's show how to scrape the same application using all three methods:

**Application Details:**
- Name: `my-webapp`
- Namespace: `prod-web`
- Metrics endpoint: `http://pod-ip:8080/metrics`
- Has a Kubernetes Service

##### Method 1: Pod Annotations (Recommended - Simplest)

**Step 1: Enable namespace in ConfigMap**
```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: ama-metrics-settings-configmap
  namespace: kube-system
data:
  pod-annotation-based-scraping: |-
    podannotationnamespaceregex = "prod-.*"
EOF
```

**Step 2: Add annotations to Deployment**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-webapp
  namespace: prod-web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-webapp
  template:
    metadata:
      labels:
        app: my-webapp
      annotations:
        prometheus.io/scrape: 'true'    # Required
        prometheus.io/path: '/metrics'   # Optional, defaults to /metrics
        prometheus.io/port: '8080'       # Required
    spec:
      containers:
      - name: webapp
        image: my-webapp:latest
        ports:
        - containerPort: 8080
          name: metrics
```

**Result:** AMA-metrics automatically discovers and scrapes both pods at `http://pod-ip:8080/metrics`

##### Method 2: ServiceMonitor (Advanced - Service Discovery)

**Step 1: Create Service**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-webapp-service
  namespace: prod-web
  labels:
    app: my-webapp-service    # ServiceMonitor will use this
spec:
  selector:
    app: my-webapp
  ports:
  - name: metrics
    port: 8080
    targetPort: 8080
```

**Step 2: Create ServiceMonitor**
```yaml
apiVersion: azmonitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-webapp-monitor
  namespace: prod-web
spec:
  selector:
    matchLabels:
      app: my-webapp-service    # Matches Service labels
  endpoints:
  - port: metrics
    path: /metrics
    interval: 30s
```

**Result:** ServiceMonitor discovers the Service, then scrapes all pods behind it

##### Method 3: PodMonitor (Advanced - Direct Pod Discovery)

**No Service required**

```yaml
apiVersion: azmonitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: my-webapp-monitor
  namespace: prod-web
spec:
  selector:
    matchLabels:
      app: my-webapp    # Matches Pod labels directly
  podMetricsEndpoints:
  - port: metrics
    path: /metrics
    interval: 30s
```

**Result:** PodMonitor directly discovers and scrapes pods with label `app=my-webapp`

##### Comparison of Results

All three methods scrape the same metrics, but:

| Aspect | Pod Annotations | ServiceMonitor | PodMonitor |
|--------|----------------|----------------|------------|
| **Setup Steps** | 2 (ConfigMap + Deployment) | 2 (Service + ServiceMonitor) | 1 (PodMonitor only) |
| **Resources Created** | 0 extra (just annotations) | 1 (ServiceMonitor CRD) | 1 (PodMonitor CRD) |
| **ConfigMap Dependency** | ✅ Yes (must enable namespace) | ❌ No | ❌ No |
| **Service Required** | ❌ No | ✅ Yes | ❌ No |
| **Scrape Interval** | Fixed (from ConfigMap) | Customizable per monitor | Customizable per monitor |
| **Label Control** | ❌ Limited | ✅ Full (relabeling) | ✅ Full (relabeling) |

**Microsoft's Recommendation:** Start with Pod Annotations. Only use ServiceMonitor/PodMonitor if you need advanced features.

---

#### Summary: Choosing the Right Method

**Start Here (90% of cases):**
```
1. Enable namespace in ConfigMap → podannotationnamespaceregex = "prod-.*"
2. Add 3 annotations to your Deployment
3. Done! Metrics automatically scraped
```

**Upgrade to CRDs only when you need:**
- Custom scrape intervals per application
- Advanced label relabeling/filtering
- Multiple endpoints per application
- TLS/authentication
- Complex service discovery

**ConfigMap Role:**
- Controls **default targets** (kubelet, KSM, cAdvisor)
- **Enables** pod annotation scraping
- Does **NOT affect** ServiceMonitor/PodMonitor (they work independently)

#### Verification and Troubleshooting

##### Check Metric Collection Status

```bash
# Verify AMA metrics pods are running
kubectl get pods -n kube-system | grep ama-metrics

# Check if your namespaces exist
kubectl get namespaces | grep prod-

# Verify pod annotations are present
kubectl describe pod -n prod-web -l app=web-app | grep -A5 Annotations

# Check service discovery
kubectl get servicemonitors -A
kubectl get podmonitors -A
```

##### Sample Grafana Queries

**KSM Metrics (No application metrics needed):**
```promql
# Pod status across prod namespaces
kube_pod_status_phase{namespace=~"prod-.*"}

# Deployment replica status  
kube_deployment_status_replicas{namespace=~"prod-.*"}

# Resource usage by namespace
sum by (namespace) (kube_pod_container_resource_requests{namespace=~"prod-.*"})
```

**Application Metrics (Requires app to expose metrics):**
```promql
# HTTP request rate (if app exposes this metric)
http_requests_total{namespace=~"prod-.*"}

# Application uptime
up{namespace=~"prod-.*", job=~".*-metrics"}
```

##### Debugging Steps

1. **Check ConfigMap Applied:**
   ```bash
   kubectl get configmap ama-metrics-settings-configmap -n kube-system -o yaml
   ```

2. **Verify AMA Pods Restarted:**
   ```bash
   kubectl get pods -n kube-system -l app=ama-metrics --sort-by=.metadata.creationTimestamp
   ```

3. **Check Prometheus Targets:**
   ```bash
   # Enable debug mode temporarily
   kubectl patch configmap ama-metrics-settings-configmap -n kube-system --type merge -p '{"data":{"debug-mode":"enabled = true"}}'
   ```

#### Summary: Complete Monitoring Strategy

This setup provides **three layers of metrics collection**:

##### 1. **Infrastructure Metrics (Always Available)**
- **Source**: Kube State Metrics (KSM) 
- **No application changes required**
- **Covers**: Pod status, deployments, services, nodes, namespaces
- **Available immediately** after enabling Azure Monitor metrics

##### 2. **Application Metrics (Pod Annotation-Based)**  
- **Source**: Applications exposing `/metrics` endpoints
- **Requires**: Application to expose Prometheus metrics + pod annotations
- **Filtered by**: `podannotationnamespaceregex = "prod-.*"`
- **Covers**: Custom business metrics, performance counters

##### 3. **Advanced Custom Metrics (CRD-Based)**
- **Source**: ServiceMonitor/PodMonitor custom resources
- **Use case**: Complex scraping scenarios, multiple endpoints
- **Benefits**: Fine-grained control, advanced filtering

##### Example Metrics in Grafana:

**Without any application changes (KSM):**
```promql
# Pod count by namespace
count by (namespace) (kube_pod_info{namespace=~"prod-.*"})

# Deployment status
kube_deployment_status_replicas{namespace=~"prod-.*"}

# Container restarts
increase(kube_pod_container_status_restarts_total{namespace=~"prod-.*"}[5m])
```

**With application metrics (Pod Annotations):**
```promql
# Only from applications that expose these metrics
http_requests_total{namespace=~"prod-.*"}
application_uptime_seconds{namespace=~"prod-.*"}
```

This approach ensures you get **comprehensive Kubernetes monitoring** immediately, with the option to add **application-specific metrics** as needed.

#### AMW configurations 

---

### Azure Managed Grafana

Azure Managed Grafana provides managed Grafana instances to view dashboards with source data from Azure Monitor Workspace.

#### Grafana Dashboard Recommendations

##### For Kube State Metrics (KSM) - Infrastructure Monitoring

**Azure Managed Grafana - Pre-built Dashboards:**

Azure Managed Grafana comes with several **ready-to-use** dashboards specifically for KSM metrics:

1. **"Kubernetes / Compute Resources / Cluster"** (Built-in)
   - Cluster-wide resource overview
   - CPU, memory, disk utilization across all nodes
   - Based on KSM + cAdvisor metrics
   - **Direct KSM metrics used**: `kube_node_status_capacity`, `kube_pod_container_resource_requests`

2. **"Kubernetes / Compute Resources / Namespace (Pods)"** (Built-in)
   - Per-namespace resource breakdown
   - Perfect for monitoring your `prod-*` namespaces
   - **Direct KSM metrics used**: `kube_pod_info`, `kube_deployment_status_replicas`

3. **"Kubernetes / Compute Resources / Pod"** (Built-in)
   - Individual pod performance and status
   - **Direct KSM metrics used**: `kube_pod_status_phase`, `kube_pod_container_status_restarts_total`

**Grafana.com - Community KSM Dashboards:**

Import these dashboard IDs directly into your Grafana:

1. **Dashboard ID: 13332** - "Kube State Metrics v2"
   - Comprehensive KSM metrics overview
   - Deployment, Pod, Node status
   - Resource utilization trends

2. **Dashboard ID: 8588** - "Kubernetes Deployment Statefulset Daemonset metrics"
   - Focuses on workload status from KSM
   - Replica counts, update status
   - **Perfect for monitoring your prod deployments**

3. **Dashboard ID: 6417** - "Kubernetes cluster monitoring (via Prometheus)"
   - Full cluster overview using KSM
   - Namespace filtering capabilities
   - Resource quotas and limits

4. **Dashboard ID: 315** - "Kubernetes cluster monitoring"
   - Classic KSM dashboard
   - Node and pod status overview
   - Simple and clean interface

5. **Dashboard ID: 10000** - "Kubernetes ALL-in-one cluster monitoring KSM"
   - Comprehensive KSM dashboard
   - Multiple views: cluster, namespace, pod levels
   - **Excellent starting point for KSM monitoring**

**Specific KSM Metrics in These Dashboards:**

These dashboards use KSM metrics that are **automatically available** without any application changes:

```promql
# Pod status and lifecycle
kube_pod_status_phase{namespace=~"prod-.*"}
kube_pod_container_status_restarts_total{namespace=~"prod-.*"}

# Deployment health
kube_deployment_status_replicas{namespace=~"prod-.*"}
kube_deployment_status_replicas_available{namespace=~"prod-.*"}
kube_deployment_status_replicas_ready{namespace=~"prod-.*"}

# Resource management
kube_pod_container_resource_requests{namespace=~"prod-.*"}
kube_pod_container_resource_limits{namespace=~"prod-.*"}

# Node status
kube_node_status_condition
kube_node_info

# Namespace information
kube_namespace_status_phase
kube_pod_info{namespace=~"prod-.*"}
```

**How to Import Pre-built KSM Dashboards:**

1. **In Grafana UI**: Go to **"+"** → **Import**
2. **Enter Dashboard ID**: Use any of the IDs above (e.g., 13332)
3. **Configure Data Source**: Select your Azure Monitor Workspace
4. **Customize**: Add namespace filter `{namespace=~"prod-.*"}` to focus on production

**Why These Work Immediately:**

- ✅ **No application code changes required**
- ✅ **KSM pod already deployed** (`ama-metrics-ksm`)
- ✅ **Metrics automatically scraped** by Azure Monitor
- ✅ **Production data already flowing** from your prod-web and prod-api namespaces

**Quick Test - Verify KSM Dashboards Work:**

1. **Access Grafana**: https://your-grafana-instance.region.grafana.azure.com
2. **Go to Explore** → Enter this query:
   ```promql
   kube_pod_info{namespace=~"prod-.*"}
   ```
3. **Expected Result**: You should see 5 pods (2 from prod-web + 3 from prod-api)
4. **Import Dashboard**: Use ID **13332** for comprehensive KSM overview

This confirms your KSM metrics are flowing and ready for dashboard visualization!

**Key KSM Metrics in These Dashboards:**
```promql
# Pod status overview
kube_pod_status_phase

# Deployment health
kube_deployment_status_replicas
kube_deployment_status_replicas_available

# Node status
kube_node_status_condition

# Resource utilization
kube_pod_container_resource_requests
kube_pod_container_resource_limits
```

##### For Application Metrics - Custom Monitoring

**Application-Specific Dashboards:**
1. **"Spring Boot Actuator Dashboard"** (if using Spring Boot)
   - HTTP request rates, response times
   - JVM memory, garbage collection
   - Thread pools, connection pools

2. **"NGINX Ingress Controller"** (for web applications)
   - Request rate, error rate
   - Response times by path
   - SSL certificate status

3. **"Custom Application Dashboard"** (build your own)
   - Business-specific metrics
   - SLA monitoring
   - Custom alerting thresholds

**Sample Custom Dashboard Queries:**
```promql
# Application availability (requires app to expose 'up' metric)
up{namespace=~"prod-.*", job=~".*-metrics"}

# HTTP request rate (requires app to expose HTTP metrics)
sum(rate(http_requests_total{namespace=~"prod-.*"}[5m])) by (namespace, service)

# Error rate
sum(rate(http_requests_total{namespace=~"prod-.*", status=~"5.."}[5m])) / 
sum(rate(http_requests_total{namespace=~"prod-.*"}[5m]))

# Response time percentiles
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket{namespace=~"prod-.*"}[5m])) by (le)
)
```

##### For ServiceMonitor/PodMonitor - Advanced Monitoring

**Custom Resource Dashboards:**
1. **"Prometheus Targets Dashboard"**
   - Monitor scraping success/failure
   - Target discovery status
   - Scrape duration metrics

2. **"Multi-Service Overview"**
   - Cross-service dependency monitoring
   - Service mesh metrics (if using Istio/Linkerd)
   - Database connection pools

#### Accessing Dashboards in Azure Managed Grafana

##### Step 1: Access Your Grafana Instance
```bash
# Get Grafana URL
az grafana show --resource-group infrarg --name amgforaks --query properties.endpoint -o tsv
```

##### Step 2: Import Pre-built Dashboards
1. **Go to Grafana UI** → **"+"** → **Import**
2. **Use Grafana.com Dashboard IDs:**
   - **315**: Kubernetes cluster monitoring
   - **8588**: Kubernetes Deployment Statefulset Daemonset metrics
   - **6417**: Kubernetes cluster monitoring (advanced)
   - **10000**: Kubernetes ALL-in-one cluster monitoring

##### Step 3: Configure Data Source
- **Data Source Type**: Prometheus
- **URL**: Your Azure Monitor Workspace endpoint
- **Authentication**: Azure AD authentication (managed identity)

##### Step 4: Customize for Your Environment
```bash
# Filter dashboards to only show prod namespaces
# In dashboard queries, add: {namespace=~"prod-.*"}

# Example customization:
# Original: kube_pod_status_phase
# Modified: kube_pod_status_phase{namespace=~"prod-.*"}
```

#### Dashboard Categories by Use Case

| **Metric Source** | **Dashboard Type** | **Primary Use Case** | **Sample Dashboards** |
|-------------------|-------------------|---------------------|----------------------|
| **KSM** | Infrastructure | Cluster health, capacity planning | Kubernetes Cluster Overview, Node Metrics |
| **cAdvisor** | Container | Resource usage, performance | Container Resource Usage, Pod Performance |
| **Pod Annotations** | Application | Business metrics, SLA monitoring | Spring Boot, Custom App Metrics |
| **ServiceMonitor** | Service | Service discovery, multi-service | Service Mesh, Microservices Overview |
| **Node Exporter** | System | Host-level metrics | Node Exporter Full, System Overview |

#### Recommended Dashboard Strategy

##### 1. **Start with Infrastructure (KSM)**
```bash
# Import these first - work immediately without app changes
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace (Pods)  
- Kubernetes / USE Method / Cluster
```

##### 2. **Add Application Dashboards**
```bash
# After implementing prometheus metrics in apps
- Custom application dashboards
- Framework-specific dashboards (Spring Boot, etc.)
- Business metrics dashboards
```

##### 3. **Advanced Monitoring**
```bash
# For complex environments
- Service mesh dashboards
- Multi-cluster dashboards
- Custom alerting dashboards
```

#### Best Practices

1. **Use Template Variables**
   ```bash
   # Add namespace filter variable
   Variable: namespace
   Query: label_values(kube_pod_info, namespace)
   Regex: /prod-.*/
   ```

2. **Set Appropriate Time Ranges**
   - Infrastructure dashboards: 1-24 hours
   - Application dashboards: 5 minutes - 6 hours
   - Capacity planning: 7-30 days

3. **Configure Alerting**
   ```promql
   # High pod restart rate
   increase(kube_pod_container_status_restarts_total{namespace=~"prod-.*"}[5m]) > 0
   
   # Deployment not ready
   kube_deployment_status_replicas{namespace=~"prod-.*"} != 
   kube_deployment_status_replicas_ready{namespace=~"prod-.*"}
   ```

This dashboard strategy ensures you have **immediate visibility** into your Kubernetes infrastructure through KSM metrics, with the flexibility to add **detailed application monitoring** as your observability requirements grow.

#### Quick Start: Verify Your Setup

##### 1. Access Your Grafana Instance
Your Grafana URL: https://your-grafana-instance.region.grafana.azure.com

##### 2. Test KSM Metrics (Available Immediately)
```promql
# Verify your prod namespaces are visible
count by (namespace) (kube_pod_info{namespace=~"prod-.*"})

# Check pod status in prod namespaces
kube_pod_status_phase{namespace=~"prod-.*"}

# View deployment status
kube_deployment_status_replicas{namespace=~"prod-.*"}
```

##### 3. Expected Results
You should see:
- **prod-web**: 2 pods (web-app deployment)
- **prod-api**: 3 pods (api-app deployment)  
- **dev-test**: Not visible (filtered out by namespace regex)

##### 4. Create Your First Dashboard
1. **Go to "+"** → **Create Dashboard**
2. **Add Panel** → **Time Series**
3. **Use Query**: `count by (namespace) (kube_pod_info{namespace=~"prod-.*"})`
4. **Panel Title**: "Production Pod Count by Namespace"
5. **Save Dashboard**

This gives you immediate production monitoring without any application code changes!
