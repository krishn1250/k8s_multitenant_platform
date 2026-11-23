# Local cluster: 1 control plane + 2 workers so pod spreading, PDBs and
# node-level chaos actually mean something.
resource "kind_cluster" "this" {
  name           = var.cluster_name
  node_image     = "kindest/node:${var.kubernetes_version}"
  wait_for_ready = true

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"
    }
    node {
      role   = "worker"
      labels = { "topology.kubernetes.io/zone" = "zone-a" }
    }
    node {
      role   = "worker"
      labels = { "topology.kubernetes.io/zone" = "zone-b" }
    }
  }
}

provider "flux" {
  kubernetes = {
    host                   = kind_cluster.this.endpoint
    client_certificate     = kind_cluster.this.client_certificate
    client_key             = kind_cluster.this.client_key
    cluster_ca_certificate = kind_cluster.this.cluster_ca_certificate
  }

  git = {
    url    = "https://github.com/${var.github_owner}/${var.github_repository}.git"
    branch = var.github_branch
    http = {
      username = "git"
      password = var.github_token
    }
  }
}

# Installs Flux controllers and commits clusters/<env>/flux-system to the repo.
# Everything after this point is managed from Git, not Terraform.
resource "flux_bootstrap_git" "this" {
  depends_on = [kind_cluster.this]

  path               = "clusters/${var.environment}"
  components_extra   = ["image-reflector-controller", "image-automation-controller"]
  interval           = "1m"
  embedded_manifests = true
}
