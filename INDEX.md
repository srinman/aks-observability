# AKS Observability Documentation Index

## 📚 Complete Documentation Suite

This repository contains comprehensive documentation for implementing Azure Monitor observability in AKS clusters.

### 📖 Available Documents

| Document | Size | Purpose |
|----------|------|---------|
| **[README.md](README.md)** | 40KB | Main documentation |
| **[QUICKREF.md](QUICKREF.md)** | 6KB | Quick command reference |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | 17KB | Architecture and diagrams |
| **[NEW_VS_EXISTING.md](NEW_VS_EXISTING.md)** | 12KB | Setup comparison |
| **[evolution.md](evolution.md)** | 112KB | Logging history |
| **[setup-observability.sh](setup-observability.sh)** | 9KB | Automated setup script |

---

## 🚀 Getting Started (Choose Your Path)

### 1. **I want to get started quickly**
   → Use the automated script: `./setup-observability.sh`
   - Interactive guided setup
   - Works for both new and existing clusters
   - Validates all steps

### 2. **I want step-by-step commands**
   → Read: [QUICKREF.md](QUICKREF.md)
   - Copy-paste ready commands
   - Environment variable setup
   - Verification commands

### 3. **I want to understand the architecture**
   → Read: [ARCHITECTURE.md](ARCHITECTURE.md)
   - Visual diagrams
   - Command explanations
   - Data flow details

### 4. **I need detailed documentation**
   → Read: [README.md](README.md)
   - Complete guide with all options
   - Detailed troubleshooting
   - Advanced configurations

### 5. **I want to compare new vs existing cluster setup**
   → Read: [NEW_VS_EXISTING.md](NEW_VS_EXISTING.md)
   - Side-by-side comparison
   - Timeline analysis
   - When to use each approach

### 6. **I want to learn logging history**
   → Read: [evolution.md](evolution.md)
   - Logging evolution from 1980s to present
   - Bare metal → Unix → Distributed Systems → Containers → Kubernetes
   - Historical context and architectural patterns

---

## 📄 Document Overview

| Document | Size | Purpose | Audience |
|----------|------|---------|----------|
| **[README.md](README.md)** | 40KB | Main documentation | Everyone |
| **[QUICKREF.md](QUICKREF.md)** | 6KB | Quick command reference | Operators |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | 17KB | Architecture and diagrams | Architects/Engineers |
| **[DAEMONSET_VS_REPLICASET.md](DAEMONSET_VS_REPLICASET.md)** | 15KB | Container Insights deep dive | Engineers/Troubleshooters |
| **[NEW_VS_EXISTING.md](NEW_VS_EXISTING.md)** | 12KB | Setup comparison | Decision makers |
| **[evolution.md](evolution.md)** | 112KB | Logging history | Learning/Research |
| **[setup-observability.sh](setup-observability.sh)** | 9KB | Automated setup script | Operators |

---

## 🎯 Use Case Matrix

| Scenario | Recommended Documents | Script |
|----------|----------------------|--------|
| **New project, need full setup** | README.md → QUICKREF.md | ✅ `./setup-observability.sh` |
| **Add monitoring to existing cluster** | NEW_VS_EXISTING.md → README.md | ✅ `./setup-observability.sh` |
| **Quick command lookup** | QUICKREF.md | ❌ |
| **Understand what's happening** | ARCHITECTURE.md | ❌ |
| **Troubleshooting issues** | README.md (troubleshooting section) | ❌ |
| **Learn about logging evolution** | evolution.md | ❌ |
| **Architecture review** | ARCHITECTURE.md → README.md | ❌ |

---

## 📖 Document Summaries

### README.md (Main Documentation)
**What it covers:**
- ✅ Complete setup instructions
- ✅ Both new and existing cluster paths
- ✅ Environment variable configuration
- ✅ All monitoring components explained
- ✅ Container Insights, Prometheus metrics, Grafana
- ✅ Troubleshooting guide
- ✅ Sample queries (KQL and PromQL)
- ✅ Dashboard recommendations

**When to read:** You need comprehensive, step-by-step guidance

---

### QUICKREF.md (Quick Reference)
**What it covers:**
- ✅ Environment variable setup
- ✅ Copy-paste commands
- ✅ Verification commands
- ✅ Common queries
- ✅ Troubleshooting checklist
- ✅ One-page cheat sheet

**When to read:** You know what you're doing and just need the commands

---

### ARCHITECTURE.md (Architecture Guide)
**What it covers:**
- ✅ Visual architecture diagrams
- ✅ Data flow explanations
- ✅ Component breakdown
- ✅ What each command does
- ✅ Pod deployment details
- ✅ Resource naming conventions
- ✅ Cost considerations

**When to read:** You need to understand how everything fits together

---

### NEW_VS_EXISTING.md (Comparison Guide)
**What it covers:**
- ✅ Side-by-side command comparison
- ✅ New cluster setup process
- ✅ Existing cluster update process
- ✅ Timeline analysis
- ✅ When to use each approach
- ✅ Feature comparison matrix

**When to read:** You're deciding between creating new vs updating existing cluster

---

### evolution.md (Logging History)
**What it covers:**
- ✅ Era 1: Bare Metal/Unix (1980s) - syslog, rsyslog, auditd
- ✅ Era 2: Traditional Enterprise Apps - Log4j, Java logging
- ✅ Era 3: Distributed Systems - Hadoop, Kafka, ELK Stack
- ✅ Era 4: Virtualization - VMware vCenter, hypervisor logs
- ✅ Era 5: Container Era - Docker logging drivers
- ✅ Era 6: Kubernetes - Fluent Bit, Prometheus, Grafana
- ✅ Mainframe systems - IBM SMF, JES2/JES3
- ✅ Historical context and architectural evolution

**When to read:** You want to understand the history and evolution of logging systems

---

### setup-observability.sh (Automation Script)
**What it does:**
- ✅ Interactive guided setup
- ✅ Validates all prerequisites
- ✅ Creates or updates cluster with monitoring
- ✅ Enables all observability components
- ✅ Verifies successful deployment
- ✅ Provides Grafana URL
- ✅ Color-coded status messages

**When to run:** You want automated, validated setup

---

## 🎓 Learning Paths

### **Beginner Path**
1. Read **README.md** overview section
2. Run `./setup-observability.sh`
3. Access Grafana and explore built-in dashboards
4. Review **QUICKREF.md** for common queries

### **Intermediate Path**
1. Read **ARCHITECTURE.md** to understand components
2. Review **NEW_VS_EXISTING.md** to choose approach
3. Follow **README.md** detailed steps manually
4. Configure custom metrics and alerts

### **Advanced Path**
1. Study **evolution.md** for historical context
2. Review **ARCHITECTURE.md** for deep dive
3. Customize setup based on **README.md** advanced sections
4. Implement custom ServiceMonitors/PodMonitors
5. Build custom Grafana dashboards

---

## 🔍 Quick Navigation

### Setup & Configuration
- [Environment Variables](README.md#environment-variables-setup)
- [New Cluster Setup](README.md#option-1-new-cluster-with-full-observability)
- [Existing Cluster Update](README.md#option-2-update-existing-cluster-with-full-observability)
- [Complete Verification](README.md#verify-complete-setup)

### Components
- [Container Insights (Logs)](README.md#container-insights---logs-from-pod-stdoutstderr)
- [Azure Monitor Workspace (Metrics)](README.md#azure-monitor-workspace---metrics-from-workloads)
- [Diagnostic Settings (Control Plane)](README.md#resource-logs---logs-from-control-plane)
- [Grafana Dashboards](README.md#azure-managed-grafana)

### Troubleshooting
- [Verification Commands](QUICKREF.md#component-verification)
- [Common Issues](ARCHITECTURE.md#troubleshooting)
- [Pod Status Checks](README.md#verification-commands)

### Queries
- [KQL Queries](QUICKREF.md#common-kql-queries)
- [Prometheus Queries](QUICKREF.md#common-prometheus-queries)
- [Sample Grafana Dashboards](README.md#grafana-dashboard-recommendations)

---

## 🛠️ Prerequisites

Before starting, ensure you have:

- ✅ Azure CLI installed and logged in
- ✅ kubectl installed
- ✅ Appropriate Azure permissions (Contributor or Owner)
- ✅ Pre-created monitoring resources in `infrarg` resource group:
  - `aksresourcelogs` (Log Analytics Workspace)
  - `amwforaks` (Azure Monitor Workspace)
  - `amgforaks` (Azure Managed Grafana)

---

## 📦 What You'll Get

After completing the setup, you'll have:

### 📝 Logs
- **Container logs** (stdout/stderr) from all pods
- **Control plane logs** (API server, scheduler, controller manager)
- **Audit logs** for compliance
- **Syslog** from worker nodes

### 📊 Metrics
- **Kube State Metrics** (pod status, deployments, services)
- **cAdvisor metrics** (container resource usage)
- **Node metrics** (CPU, memory, disk, network)
- **Custom application metrics** (if exposed)

### 📈 Visualization
- **Pre-built Kubernetes dashboards** in Grafana
- **Custom dashboard** capability
- **Alerting** on metrics and logs
- **Multi-source queries** (metrics + logs)

---

## 🚨 Important Notes

### Resource Naming
All monitoring resources are pre-created in the `infrarg` resource group:
- **Log Analytics**: `aksresourcelogs`
- **Monitor Workspace**: `amwforaks`
- **Grafana**: `amgforaks`

### Cost Implications
- Log Analytics: ~$2.30/GB ingested
- Azure Monitor Workspace: ~$0.28 per million samples
- Grafana: ~$8.40/hour for Standard tier

See [ARCHITECTURE.md - Cost Considerations](ARCHITECTURE.md#cost-considerations) for optimization tips.

### Metrics Duplication
Always disable Container Insights metrics collection when using Azure Monitor Workspace to avoid:
- ❌ Double ingestion costs
- ❌ Conflicting metric sources
- ❌ Confusion in dashboards

This is handled automatically by the setup script and documented in all guides.

---

## 🤝 Support & Contribution

### Questions?
1. Check the relevant documentation
2. Review [troubleshooting sections](ARCHITECTURE.md#troubleshooting)
3. Verify setup using [verification commands](QUICKREF.md#component-verification)

### Found an Issue?
- Check if it's covered in troubleshooting
- Verify environment variables are set correctly
- Review pod logs in kube-system namespace

---

## 📋 Checklist for Success

Before starting:
- [ ] Have Azure CLI access
- [ ] Have kubectl installed
- [ ] Monitoring resources created in `infrarg`
- [ ] Decided on new vs existing cluster
- [ ] Read appropriate documentation

During setup:
- [ ] Set environment variables
- [ ] Run appropriate commands for your scenario
- [ ] Wait for pods to be ready
- [ ] Enable diagnostic settings
- [ ] Disable duplicate metrics collection

After setup:
- [ ] Verify all pods are running
- [ ] Access Grafana successfully
- [ ] Query logs in Log Analytics
- [ ] View metrics in Grafana
- [ ] Import recommended dashboards

---

## 🎉 Next Steps After Setup

1. **Explore Grafana**
   - Access the Grafana URL
   - Review built-in Kubernetes dashboards
   - Import community dashboards (IDs: 315, 8588, 13332)

2. **Query Your Data**
   - Run sample KQL queries in Log Analytics
   - Test Prometheus queries in Grafana
   - Create custom queries for your needs

3. **Set Up Alerts**
   - Configure alerts for critical metrics
   - Set up log-based alerts
   - Define notification channels

4. **Optimize**
   - Review ingestion costs
   - Configure log retention
   - Tune metric collection intervals

5. **Learn More**
   - Read [evolution.md](evolution.md) for logging history
   - Study [ARCHITECTURE.md](ARCHITECTURE.md) for deep understanding
   - Explore advanced configurations in [README.md](README.md)

---

## 📞 Getting Help

**Documentation Order for Troubleshooting:**
1. [QUICKREF.md](QUICKREF.md) - Quick verification commands
2. [ARCHITECTURE.md](ARCHITECTURE.md) - Troubleshooting section
3. [README.md](README.md) - Detailed troubleshooting guide

**Common Issues:**
- Pods not starting → Check [README.md verification section](README.md#verification-commands)
- Metrics not showing → See [ARCHITECTURE.md troubleshooting](ARCHITECTURE.md#metrics-not-appearing)
- Logs not appearing → Check [ARCHITECTURE.md troubleshooting](ARCHITECTURE.md#logs-not-appearing)

---

## 🏆 Success Criteria

Your setup is complete when:
- ✅ All monitoring pods are running in kube-system
- ✅ You can query container logs in Log Analytics
- ✅ You can see metrics in Grafana
- ✅ Control plane logs are flowing
- ✅ Built-in Grafana dashboards show data

---

**Happy Monitoring! 📊 🎉**

*Last updated: October 2025*
