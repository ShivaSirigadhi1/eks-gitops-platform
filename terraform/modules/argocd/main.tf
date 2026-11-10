resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.8.0"
  namespace  = "argocd"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "configs.cm.application.resourceTrackingMethod"
    value = "annotation"
  }
  set {
    name  = "configs.cm.url"
    value = var.argocd_url
  }
  set {
    name  = "configs.rbac.defaultPolicy"
    value = "role:readonly"
  }
  set {
    name  = "configs.rbac.scopes"
    value = "[groups]"
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Argo CD Project for platform team
resource "kubernetes_manifest" "platform_project" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "platform"
      namespace = "argocd"
    }
    spec = {
      description = "Platform team project with full access"
      sourceRepos = ["*"]
      destinations = [{
        namespace = "*"
        server    = "*"
      }]
      clusterResourceWhitelist = [{"group": "*", "kind": "*"}]
      namespaceResourceWhitelist = [{"group": "*", "kind": "*"}]
      roles = [{
        name        = "admin"
        description = "Platform admin"
        policies    = ["p, proj:platform:admin, applications, *, */*, allow"]
        groups      = ["platform-admins"]
      }]
    }
  }
}

# Argo CD Project for workloads
resource "kubernetes_manifest" "workloads_project" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "AppProject"
    metadata = {
      name      = "workloads"
      namespace = "argocd"
    }
    spec = {
      description = "Workload project for application teams"
      sourceRepos = ["https://github.com/your-org/eks-gitops-platform"]
      destinations = [{
        namespace = "blueprint-dev"
        server    = "https://kubernetes.default.svc"
      }, {
        namespace = "blueprint-staging"
        server    = "https://kubernetes.default.svc"
      }, {
        namespace = "blueprint-production"
        server    = "https://kubernetes.default.svc"
      }]
      clusterResourceWhitelist = [{"group": "", "kind": "Namespace"}]
      namespaceResourceWhitelist = [{"group": "*", "kind": "*"}]
      roles = [{
        name        = "developer"
        description = "Application developer"
        policies    = ["p, proj:workloads:developer, applications, get, workloads/*, allow", "p, proj:workloads:developer, applications, sync, workloads/*, allow"]
        groups      = ["app-developers"]
      }]
    }
  }
}
