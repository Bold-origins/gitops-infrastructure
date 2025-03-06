# App Flow Document

## Introduction
This document describes the complete user journey through all web interfaces available in the Local Kubernetes Cluster. It serves as a roadmap for the AI coding model to understand how users navigate through the system.

## Kubernetes Dashboard Flow

### Dashboard Access
After setting up the cluster, the user first accesses the Kubernetes Dashboard by visiting http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/http:kubernetes-dashboard:/proxy/ in their browser. This dashboard serves as the central visualization interface for the entire Kubernetes cluster.

### Dashboard Home
Upon accessing the dashboard, the user is presented with the overview page displaying the cluster status. The top navigation includes tabs for Workloads, Service Discovery, Config and Storage, and Settings. The sidebar offers quick access to Cluster, Namespaces, Nodes, Workloads, Discovery and Load Balancing, Config and Storage sections.

### Workloads Section
From the dashboard home, the user clicks on Workloads to see all deployments, pods, replica sets, and stateful sets running in the cluster. This view allows users to monitor the status of all applications and infrastructure components. Users can click on any specific workload to view detailed information, logs, and events.

### Namespaces Navigation
The user navigates to the Namespaces section to view all available namespaces. Here they can switch between different namespaces such as default, kube-system, monitoring, security, and application-specific namespaces to view resources isolated to those areas.

### Resource Details
When viewing any resource (such as a pod or deployment), the user sees tabs for Overview, YAML, Events, and Logs. The Overview shows the resource status and metadata. The YAML tab displays the full configuration. The Events tab shows relevant cluster events. The Logs tab displays container logs for debugging.

## Vault Interface Flow

### Vault Login
After accessing https://vault.local in their browser and accepting the self-signed certificate warning, the user is presented with the Vault login screen. They enter the root token (initially set during setup) to authenticate.

### Vault Secrets
Upon successful login, the user sees the Secrets page. The left sidebar displays options for Secrets, Access, Policies, and Tools. The main content area shows available secret engines including Key/Value, PKI, and Transit.

### Managing KV Secrets
The user clicks on the Key/Value secrets engine to browse, create, and manage secrets. They navigate through the path hierarchy, clicking on folders to drill down. To create a new secret, they click the Create Secret button, enter the path, key, and value information, then save it.

### Secret Access Control
From the secrets view, the user navigates to the Access section to manage authentication methods and identity. Here they can create and manage policies that control access to different secrets, allowing fine-grained permissions for different users and applications.

## Grafana Dashboard Flow

### Grafana Login
The user visits https://grafana.local and is presented with the Grafana login screen. They log in using the default admin credentials (which they should change after first login).

### Grafana Home
After logging in, the user sees the Grafana home dashboard with sections for Recent Dashboards, Starred, and Home. The left sidebar provides navigation to Dashboards, Explore, Alerting, Configuration, and Server Admin sections.

### Dashboard Selection
The user clicks on Dashboards to see available dashboard categories. They navigate through folders organized by component (Kubernetes, Prometheus, Applications) and select a specific dashboard to view metrics.

### Metric Exploration
Within a dashboard, the user views pre-configured panels displaying various metrics. They can adjust the time range using the time picker in the top right corner. For deeper analysis, they hover over graphs to see specific values or click on a panel and select Edit to modify the query or visualization.

### Creating New Dashboards
To create custom dashboards, the user clicks the + icon in the left sidebar and selects Dashboard. They then add panels by clicking Add Panel, select the data source (Prometheus), build queries using the query builder, and customize the visualization.

## Prometheus Interface Flow

### Prometheus Home
When accessing https://prometheus.local, the user lands on the Prometheus home page. The top navigation includes tabs for Alerts, Graph, Status, and Help.

### Query Execution
The user clicks on the Graph tab to run queries. They enter PromQL queries in the expression field and click Execute to view results. The results are displayed as both a graph and table below the query input.

### Target Status
From the home page, the user navigates to Status > Targets to view all configured scrape targets and their health status. This page shows which endpoints Prometheus is monitoring and whether they're up or down.

### Alert Rules
The user clicks on Alerts to view all configured alert rules and their current status. The page displays whether alerts are firing, pending, or inactive, helping users understand the current state of the monitoring system.

### Configuration
In the Status section, the user can view the Prometheus configuration including scrape configs, alert rules, and recording rules by selecting the appropriate submenu item.

## MinIO Browser Flow

### MinIO Login
The user accesses https://minio.local and logs in with the default credentials provided during setup.

### Bucket View
After logging in, the user sees the main MinIO browser interface showing available buckets (storage containers). The left sidebar provides navigation to buckets and settings.

### Creating Buckets
To create a new storage area, the user clicks the Create Bucket button, enters a bucket name, and confirms creation. The new bucket appears in the bucket list.

### File Operations
After selecting a bucket, the user sees its contents in the main view. They can upload files by clicking the Upload button, create folders using the Create Folder button, or perform actions on existing files such as download, delete, or share by using the context menu.

### Access Management
From the main interface, the user navigates to the Identity menu to manage users, groups, and access policies. Here they can create new users, assign them to groups, and control access to different buckets.

## Alertmanager Interface Flow

### Alertmanager Overview
When visiting https://alertmanager.local, the user sees the current alerts page showing all active alerts. The navigation tabs include Alerts, Silences, and Status.

### Alert Management
On the Alerts page, the user views all currently firing alerts grouped by various labels. They can click on any alert to see detailed information including annotations, labels, and the source.

### Creating Silences
To temporarily mute notifications, the user clicks on the Silences tab and then New Silence. They fill in the start and end times, add matchers to specify which alerts to silence, provide a comment explaining the reason, and click Create.

### Viewing Status
The user clicks on the Status tab to view the current configuration of Alertmanager including receivers, route tree, and other important configuration details that determine how alerts are processed and routed.

## Common Navigation Patterns

### Service Discovery
Users typically begin at the Kubernetes Dashboard to get an overview of the cluster. From there, they navigate to specific service interfaces based on their needs - Vault for secrets management, Grafana for visualization, Prometheus for raw metrics, MinIO for object storage, and Alertmanager for handling alerts.

### Context Switching
Users frequently switch between interfaces to correlate information. For example, they may see an alert in Alertmanager, check the metrics in Prometheus, visualize the trend in Grafana, and then examine the affected workload in the Kubernetes Dashboard.

### Troubleshooting Flow
When troubleshooting, users typically follow a flow from alert notification, to metrics inspection, to log examination, to Kubernetes resource investigation. This cross-application journey helps diagnose and resolve issues within the cluster. 