output "kubeconfig_path" {
  description = "kind writes the context into your default kubeconfig."
  value       = kind_cluster.this.kubeconfig_path
}

output "cluster_context" {
  value = "kind-${var.cluster_name}"
}
