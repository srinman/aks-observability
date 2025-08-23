# AKS Observability Guide

This guide provides comprehensive instructions for implementing observability in Azure Kubernetes Service (AKS) clusters using Azure Monitor, including logs, metrics, and visualization components.

## Table of Contents

- [Overview](#overview)
- [Azure Monitor Components](#azure-monitor-components)
- [Monitoring Data Types](#monitoring-data-types)
  - [Activity Logs](#activity-logs)
  - [Platform Metrics](#platform-metrics)
  - [Resource Logs](#resource-logs)
  - [Syslog](#syslog)
- [Container Insights Configuration](#container-insights-configuration)
- [Azure Monitor Workspace Configuration](#azure-monitor-workspace-configuration)
- [Azure Managed Grafana](#azure-managed-grafana)

## Overview

This document covers the implementation of observability for AKS clusters using Azure's native monitoring services. The solution includes log collection, metric collection, and visualization capabilities.

## Azure Monitor Components

The following Azure resources are required for complete AKS observability:

- **Log Analytics Workspace (LAW)** - Resource to store & view log data 
- **Azure Monitor Workspace (AMW)** - Resource to store and (limited view of) prometheus metrics  
- **Azure Managed Grafana (AMG)** - Resource to build/view dashboards - source can be AMW   

## Monitoring Data Types

### Activity Logs

Activity logs provide audit trail information for AKS cluster management operations.

**Documentation:**
- https://learn.microsoft.com/en-us/azure/aks/monitor-aks-reference#activity-log  
- https://learn.microsoft.com/en-us/azure/role-based-access-control/permissions/containers#microsoftcontainerservice  

### Platform Metrics

Platform metrics provide performance and health information about the AKS cluster infrastructure.

**Documentation:**
- https://learn.microsoft.com/en-us/azure/aks/monitor-aks-reference#metrics  
- https://learn.microsoft.com/en-us/azure/aks/monitor-aks-reference#supported-metrics-for-microsoftcontainerservicemanagedclusters   

**Baseline Metrics:**
Refer AMBA for baseline metrics to monitor and alert   
https://azure.github.io/azure-monitor-baseline-alerts/services/ContainerService/managedClusters/  

### Resource Logs

Resource logs capture information from the AKS control plane components.

**Documentation:**
- https://learn.microsoft.com/en-us/azure/aks/monitor-aks?tabs=cilium#aks-control-plane-resource-logs  
- https://learn.microsoft.com/en-us/azure/aks/monitor-aks?tabs=cilium#sample-log-queries  

**Sample Query:**
```kusto
AKSControlPlane
| where Category == "kube-apiserver"
```

### Syslog

Syslog provides system-level logs from worker nodes.

**Cluster Creation with Monitoring:**
```bash
az aks create -g <clusterResourceGroup> -n <clusterName> --enable-managed-identity --node-count 1 --enable-addons monitoring --data-collection-settings dataCollectionSettings.json --generate-ssh-keys  
```

## Container Insights Configuration

Container Insights provides logs from pod stdout/stderr.

> **Important**: Container Insights collect metric data in addition to logs. This must be disabled when AMW is used for metrics collection.

### Enabling Container Insights

Container Insights uses AMA agent for log collection.

```bash
export lawrid=$(az monitor log-analytics workspace show --resource-group demolabrg --name demolabakscontainerlogs --query id -o tsv)

az aks enable-addons \
  --addon monitoring \
  --name keda-training-aks \
  --resource-group keda-rg \
  --workspace-resource-id $lawrid
```

### Verification Commands

```bash
kubectl get ds ama-logs --namespace=kube-system
kubectl get deployment ama-logs-rs --namespace=kube-system
```

**Review pods:**
```bash
k describe pod ama-logs-rs-5666f4f584-5qb7l  -n kube-system | grep -i image: 
    Image:         mcr.microsoft.com/aks/msi/addon-token-adapter:master.250604.1
    Image:          mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.28
k describe pod ama-logs-d6jxv  -n kube-system | grep -i image: 
    Image:         mcr.microsoft.com/aks/msi/addon-token-adapter:master.250604.1
    Image:          mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.28
    Image:          mcr.microsoft.com/azuremonitor/containerinsights/ciprod:3.1.28
```

**Cluster Status:**
```bash
az aks show --resource-group keda-rg --name keda-training-aks
```

In portal, check log analytics workspace for logs: 
table: ContainerLogV2   

## Azure Monitor Workspace Configuration

Azure Monitor Workspace enables metrics collection from workloads using Prometheus.

### Component Overview

The following components are deployed for metrics collection:

- **ama-metrics pods** - Main metrics collection
- **ama-metrics-ksm pod** - Kube State Metrics
- **ama-metrics-node daemonset pods** (one per node) - Node-level metrics collection
- **ama-metrics-operator-targets pod** - Operator for managing metric targets

### Enabling Azure Monitor Metrics

```bash
export amwrid=$(az monitor account show --resource-group infrarg --name amwforaks --query id -o tsv)
export amgrid=$(az grafana show --resource-group infrarg --name amgforaks --query id -o tsv)

az aks update \
  --enable-azure-monitor-metrics \
  --name keda-training-aks \
  --resource-group keda-rg \
  --azure-monitor-workspace-resource-id $amwrid \
  --grafana-resource-id $amgrid
```

### Verification Commands

```bash
kubectl get pods -n kube-system | grep -E "(ama-metrics|prometheus)"

kubectl get pods -n kube-system -o custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[*].image | grep -E "(ama-metrics|prometheus)"
```

### AMA Metrics Settings 

Configure custom scraping and settings using configmaps in kube-system namespace.

#### Configure pod annotation-based scraping for prod- namespaces:

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

#### Pod annotations required for scraping:
```yaml
metadata:   
  annotations:
    prometheus.io/scrape: 'true'
    prometheus.io/path: '/metrics'    # optional, defaults to /metrics
    prometheus.io/port: '8080'        # required - port where metrics are exposed
```

**Reference:** https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-configuration

### Understanding Metrics Collection Types

#### Default Metrics Collection with Kube State Metrics (KSM)

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

#### Pod Annotation-Based Scraping

This method requires applications to expose Prometheus metrics and uses pod annotations for discovery.

**When to use pod annotations:**
- Applications that expose custom business metrics
- Spring Boot applications with `/actuator/prometheus`
- Custom applications with `/metrics` endpoints

### Practical Example: Namespace-Based Scraping

#### Creating Test Namespaces and Workloads

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

#### Why Use Namespace Regex `prod-.*`?

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

### Advanced Scraping with Custom Resource Definitions (CRDs)

#### When to Use ServiceMonitor vs PodMonitor

**ServiceMonitor** - Use when you have Kubernetes Services:
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

#### When to Use Each Approach:

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **Pod Annotations** | Simple application metrics | Easy setup, no CRDs needed | Limited configuration options |
| **ServiceMonitor** | Service-level monitoring | More flexible, service discovery | Requires services |
| **PodMonitor** | Pod-level monitoring | Direct pod access, fine control | More complex configuration |

**Pod Annotations** → Simple cases, quick setup
**ServiceMonitor** → Production applications with services  
**PodMonitor** → Advanced scenarios, specific pod targeting

**Reference:** https://learn.microsoft.com/en-us/azure/azure-monitor/containers/prometheus-metrics-scrape-crd

### Verification and Troubleshooting

#### Check Metric Collection Status

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

#### Sample Grafana Queries

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

#### Debugging Steps

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

### Summary: Complete Monitoring Strategy

This setup provides **three layers of metrics collection**:

#### 1. **Infrastructure Metrics (Always Available)**
- **Source**: Kube State Metrics (KSM) 
- **No application changes required**
- **Covers**: Pod status, deployments, services, nodes, namespaces
- **Available immediately** after enabling Azure Monitor metrics

#### 2. **Application Metrics (Pod Annotation-Based)**  
- **Source**: Applications exposing `/metrics` endpoints
- **Requires**: Application to expose Prometheus metrics + pod annotations
- **Filtered by**: `podannotationnamespaceregex = "prod-.*"`
- **Covers**: Custom business metrics, performance counters

#### 3. **Advanced Custom Metrics (CRD-Based)**
- **Source**: ServiceMonitor/PodMonitor custom resources
- **Use case**: Complex scraping scenarios, multiple endpoints
- **Benefits**: Fine-grained control, advanced filtering

#### Example Metrics in Grafana:

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

### AMW configurations 

## Azure Managed Grafana

Azure Managed Grafana provides managed Grafana instances to view dashboards with source data from Azure Monitor Workspace.

### Grafana Dashboard Recommendations

#### For Kube State Metrics (KSM) - Infrastructure Monitoring

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

1. **Access Grafana**: https://amgforaks-a8bmc4hxhcbpgfbn.eus2.grafana.azure.com
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

#### For Application Metrics - Custom Monitoring

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

#### For ServiceMonitor/PodMonitor - Advanced Monitoring

**Custom Resource Dashboards:**
1. **"Prometheus Targets Dashboard"**
   - Monitor scraping success/failure
   - Target discovery status
   - Scrape duration metrics

2. **"Multi-Service Overview"**
   - Cross-service dependency monitoring
   - Service mesh metrics (if using Istio/Linkerd)
   - Database connection pools

### Accessing Dashboards in Azure Managed Grafana

#### Step 1: Access Your Grafana Instance
```bash
# Get Grafana URL
az grafana show --resource-group infrarg --name amgforaks --query properties.endpoint -o tsv
```

#### Step 2: Import Pre-built Dashboards
1. **Go to Grafana UI** → **"+"** → **Import**
2. **Use Grafana.com Dashboard IDs:**
   - **315**: Kubernetes cluster monitoring
   - **8588**: Kubernetes Deployment Statefulset Daemonset metrics
   - **6417**: Kubernetes cluster monitoring (advanced)
   - **10000**: Kubernetes ALL-in-one cluster monitoring

#### Step 3: Configure Data Source
- **Data Source Type**: Prometheus
- **URL**: Your Azure Monitor Workspace endpoint
- **Authentication**: Azure AD authentication (managed identity)

#### Step 4: Customize for Your Environment
```bash
# Filter dashboards to only show prod namespaces
# In dashboard queries, add: {namespace=~"prod-.*"}

# Example customization:
# Original: kube_pod_status_phase
# Modified: kube_pod_status_phase{namespace=~"prod-.*"}
```

### Dashboard Categories by Use Case

| **Metric Source** | **Dashboard Type** | **Primary Use Case** | **Sample Dashboards** |
|-------------------|-------------------|---------------------|----------------------|
| **KSM** | Infrastructure | Cluster health, capacity planning | Kubernetes Cluster Overview, Node Metrics |
| **cAdvisor** | Container | Resource usage, performance | Container Resource Usage, Pod Performance |
| **Pod Annotations** | Application | Business metrics, SLA monitoring | Spring Boot, Custom App Metrics |
| **ServiceMonitor** | Service | Service discovery, multi-service | Service Mesh, Microservices Overview |
| **Node Exporter** | System | Host-level metrics | Node Exporter Full, System Overview |

### Recommended Dashboard Strategy

#### 1. **Start with Infrastructure (KSM)**
```bash
# Import these first - work immediately without app changes
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace (Pods)  
- Kubernetes / USE Method / Cluster
```

#### 2. **Add Application Dashboards**
```bash
# After implementing prometheus metrics in apps
- Custom application dashboards
- Framework-specific dashboards (Spring Boot, etc.)
- Business metrics dashboards
```

#### 3. **Advanced Monitoring**
```bash
# For complex environments
- Service mesh dashboards
- Multi-cluster dashboards
- Custom alerting dashboards
```

### Best Practices

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

### Quick Start: Verify Your Setup

#### 1. Access Your Grafana Instance
Your Grafana URL: https://amgforaks-a8bmc4hxhcbpgfbn.eus2.grafana.azure.com

#### 2. Test KSM Metrics (Available Immediately)
```promql
# Verify your prod namespaces are visible
count by (namespace) (kube_pod_info{namespace=~"prod-.*"})

# Check pod status in prod namespaces
kube_pod_status_phase{namespace=~"prod-.*"}

# View deployment status
kube_deployment_status_replicas{namespace=~"prod-.*"}
```

#### 3. Expected Results
You should see:
- **prod-web**: 2 pods (web-app deployment)
- **prod-api**: 3 pods (api-app deployment)  
- **dev-test**: Not visible (filtered out by namespace regex)

#### 4. Create Your First Dashboard
1. **Go to "+"** → **Create Dashboard**
2. **Add Panel** → **Time Series**
3. **Use Query**: `count by (namespace) (kube_pod_info{namespace=~"prod-.*"})`
4. **Panel Title**: "Production Pod Count by Namespace"
5. **Save Dashboard**

This gives you immediate production monitoring without any application code changes!
