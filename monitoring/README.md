# Monitoring with Lens and Prometheus

## Kubernetes Lens

Lens is a desktop IDE for working with Kubernetes clusters. It provides a graphical interface for viewing cluster status, managing resources, checking logs, and monitoring resource usage.

In this project, Lens is used to connect to the Kubernetes cluster and visually monitor its state.

## Metrics Server

Metrics Server was installed in the `kube-system` namespace using the official `v0.9.1` manifest.

A local copy of the manifest is stored in `metrics-server.yaml`. Installation:

```bash
kubectl apply -f monitoring/metrics-server.yaml
```

To check metric availability:

```bash
kubectl top nodes
kubectl top pods -A
```

Metrics Server provides basic CPU and memory usage metrics for Kubernetes nodes and Pods.

## Prometheus

The `kube-prometheus-stack` was installed through Helm in Lens to collect and store metrics.

- Helm repository: `prometheus-community`
- Chart: `kube-prometheus-stack`
- Chart version: `92.17.1`
- Namespace: `monitoring`
- Release: `kube-prometheus-stack`

The chart was installed using its default Helm values.

## Lens Metrics

In the connected cluster's Lens settings, Prometheus was selected as the metrics source.

Lens automatically detected Prometheus Operator in the cluster at:

`monitoring/services/prometheus-operated:9090`

After configuration, Lens displayed CPU and memory usage metrics, along with other resource metrics for nodes and Pods.

## Result

Metrics Server and Prometheus are running in the cluster. Lens is connected to the cluster and uses Prometheus to display metrics.

Metrics Server provides basic Kubernetes metrics, including those used by `kubectl top`, while Prometheus collects and stores time-series metrics for monitoring.