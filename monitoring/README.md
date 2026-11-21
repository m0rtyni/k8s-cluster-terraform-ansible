# Kubernetes Infrastructure Monitoring

## Overview

The monitoring stack provides visibility into Kubernetes cluster health, workload performance, application logs, Kubernetes events, and MongoDB metrics.

The solution combines Prometheus-based infrastructure monitoring with Loki-based centralized application logging and Grafana alerting.

## Components and Setup

### Infrastructure Monitoring

- **Lens** — graphical interface for cluster management and resource monitoring.
- **Metrics Server v0.9.1** — provides basic CPU and memory metrics for `kubectl top`.
- **Prometheus** — installed using the `kube-prometheus-stack` Helm chart (v93.4.0) in the `monitoring` namespace.
- **Grafana** — visualization platform using Prometheus and Loki as data sources.
- **Kubernetes Events Exporter** — collects selected Kubernetes events and exposes them as Prometheus metrics.
- **MongoDB Exporter** — exposes MongoDB metrics for Prometheus.

### Application Logging

- **Loki** — centralized log aggregation system for Kubernetes application logs.
- **Grafana Alloy** — collects container logs from Kubernetes Pods and forwards them to Loki.
- **Grafana Loki Data Source** — allows searching and visualizing application logs using Grafana Explore.

Loki and Alloy were deployed using Helm charts through Ansible.

The logging pipeline follows this architecture:

`Nginx Pod → Grafana Alloy → Loki → Grafana`

The test application runs Nginx (`nginx:1.27.5`) in the `app-logging` namespace.

Infrastructure monitoring configurations are stored in `prometheus/values.yaml`. Loki and Alloy configurations are stored in their respective directories.

Custom Grafana dashboards are stored in `grafana/dashboards/` and provisioned through a ConfigMap.

## Dashboards and Selected Metrics

| Dashboard | Metrics | Purpose |
|---|---|---|
| Kubernetes - Pods | Container restarts, OOMKilled, memory limits | Detect unstable containers and memory problems |
| Kubernetes Events | Event counts, reasons, exporter health | Identify scheduling, storage, and workload issues |
| Kubernetes Nodes | CPU and memory usage | Monitor node resource utilization |
| MongoDB Monitoring | `mongodb_up`, `mongodb_asserts_total`, `mongodb_connections` | Monitor database availability and activity |

These metrics cover the main areas of infrastructure health: resource usage, workload stability, Kubernetes events, and database operation.

## Application Log Collection

Grafana Alloy collects Kubernetes Pod logs and forwards them to Loki.

Loki is configured as a Grafana data source, allowing application logs to be queried through Grafana Explore using LogQL.

The logging pipeline was verified by generating HTTP requests to the test Nginx application and confirming that the corresponding log entries appeared in Grafana.

## Alerts

### Infrastructure Alerts

Custom Kubernetes alert rules are stored in `prometheus/alert-rules.yaml`.

The `KubernetesContainerOomKiller` rule detects containers terminated due to memory exhaustion (`OOMKilled`). The rule is based on the Kubernetes alerts collection from [awesome-prometheus-alerts](https://github.com/samber/awesome-prometheus-alerts).

### Application Alerts

A Grafana alert rule named `NginxHTTP5xxErrors` monitors HTTP 5xx errors in Nginx application logs using LogQL.

A Telegram contact point is configured in Grafana to deliver alert notifications.

The alerting pipeline follows this architecture:

`Loki → Grafana Alerting → Telegram`

### Alert Testing

The alerting configuration was tested by intentionally generating HTTP 500 responses from the Nginx test application.

The `/error` endpoint was used to simulate application errors.

The following results were verified:

- HTTP 500 responses were generated successfully.
- Corresponding error logs were collected by Alloy and stored in Loki.
- The `NginxHTTP5xxErrors` alert rule entered the Firing state.
- Telegram successfully received the actual alert notification.

This confirmed the complete logging and alerting pipeline.

## Challenges and Solutions

- **Calico networking:** an obsolete custom route bypassed Calico networking. The `pod-network-route` service was disabled and removed from Ansible provisioning.
- **Grafana connectivity:** Prometheus datasource timeouts were investigated and resolved.
- **Kubernetes Events:** deployed an Events Exporter and configured a ServiceMonitor for Prometheus scraping.
- **MongoDB metrics:** deployed MongoDB Exporter and configured authentication using Kubernetes Secrets.
- **Dashboard provisioning:** configured ConfigMap-based provisioning. The Kubernetes Nodes dashboard remains accessible, although Grafana reports an internal provisioning conflict for it.
- **Application log collection:** configured Grafana Alloy to discover Kubernetes Pod logs and forward them to Loki.
- **Alert notifications:** configured Grafana Telegram integration and verified actual alert delivery after generating HTTP 500 responses.

## Access

When port-forwarding is active:

- Grafana: [http://localhost:3000](http://localhost:3000)
- Prometheus: [http://localhost:9090](http://localhost:9090)

## Result

The cluster now provides centralized infrastructure monitoring and application logging.

Prometheus collects infrastructure metrics, while Loki and Grafana Alloy provide centralized application log collection. Grafana provides dashboards, log exploration, and alerting with Telegram notifications.

Both infrastructure monitoring and application logging and alerting have been tested successfully.