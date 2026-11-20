# Kubernetes Infrastructure Monitoring

## Overview

The monitoring stack provides visibility into Kubernetes cluster health, workload performance, Kubernetes events, and MongoDB metrics.

## Components and Setup

- **Lens** — graphical interface for cluster management and resource monitoring.
- **Metrics Server v0.9.1** — provides basic CPU and memory metrics for `kubectl top`.
- **Prometheus** — installed using `kube-prometheus-stack` Helm chart (v93.4.0) in the `monitoring` namespace.
- **Grafana** — uses Prometheus as a data source and provides custom dashboards.
- **Kubernetes Events Exporter** — collects selected Kubernetes events and exposes them as Prometheus metrics.
- **MongoDB Exporter** — exposes MongoDB metrics for Prometheus.

Prometheus and Grafana settings are stored in `prometheus/values.yaml`. Exporter configurations are stored in their respective directories.

Custom Grafana dashboards are stored in `grafana/dashboards/` and provisioned through a ConfigMap.

## Dashboards and Selected Metrics

| Dashboard | Metrics | Purpose |
|---|---|---|
| Kubernetes - Pods | Container restarts, OOMKilled, memory limits | Detect unstable containers and memory problems |
| Kubernetes Events | Event counts, reasons, exporter health | Identify scheduling, storage, and workload issues |
| Kubernetes Nodes | CPU and memory usage | Monitor node resource utilization |
| MongoDB Monitoring | `mongodb_up`, `mongodb_asserts_total`, `mongodb_connections` | Monitor database availability and activity |

These metrics were selected to cover the main areas of infrastructure health: resource usage, workload stability, Kubernetes events, and database operation.

## Alerts

Custom Kubernetes alert rules are stored in `prometheus/alert-rules.yaml`.

The `KubernetesContainerOomKiller` rule detects containers terminated due to memory exhaustion (`OOMKilled`). The rule is based on the Kubernetes alerts collection from [awesome-prometheus-alerts](https://github.com/samber/awesome-prometheus-alerts).

## Challenges and Solutions

- **Calico networking:** an obsolete custom route bypassed Calico networking. The `pod-network-route` service was disabled and removed from Ansible provisioning.
- **Grafana connectivity:** Prometheus datasource timeouts were investigated and resolved.
- **Kubernetes Events:** deployed an Events Exporter and configured a ServiceMonitor for Prometheus scraping.
- **MongoDB metrics:** deployed MongoDB Exporter and configured authentication using Kubernetes Secrets.
- **Dashboard provisioning:** configured ConfigMap-based provisioning. The Kubernetes Nodes dashboard remains accessible, although Grafana reports an internal provisioning conflict for it.

## Access

When port-forwarding is active:

- Grafana: `http://localhost:3000`
- Prometheus: `http://localhost:9090`

## Result

The cluster now has centralized metrics collection with Prometheus, visualization through Grafana, Kubernetes event monitoring, MongoDB metrics, and custom dashboards.