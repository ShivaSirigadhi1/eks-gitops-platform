resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "61.3.0"
  namespace  = "monitoring"
  create_namespace = true

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "15d"
  }
  set {
    name  = "prometheus.prometheusSpec.retentionSize"
    value = "10GB"
  }
  set {
    name  = "grafana.enabled"
    value = "true"
  }
  set {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "alertmanager.enabled"
    value = "true"
  }
}

resource "kubernetes_manifest" "servicemonitor_crd" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "otel-collector"
      namespace = "monitoring"
    }
    spec = {
      selector = {
        matchLabels = {
          "app.kubernetes.io/name" = "opentelemetry-collector"
        }
      }
      endpoints = [{
        port = "metrics"
        interval = "30s"
      }]
    }
  }
}
