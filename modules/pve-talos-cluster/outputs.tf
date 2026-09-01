output "frr_bgp_config" {
  description = "Rendered FRR BGP configuration"
  sensitive   = true
  value = templatefile("${path.module}/templates/frr-bgp.conf.tmpl", {
    cluster_name = var.talos_cluster_name
    cilium_neighbor_ips = [
      for node in concat(local.controller_nodes, local.worker_nodes) : node.ipv4
    ]
    cilium_bgp_remote_asn       = var.cilium_bgp_remote_asn
    cilium_bgp_remote_router_id = split("/", var.cilium_lb_svc_cidr)[0]
    cilium_bgp_local_asn        = var.cilium_bgp_local_asn
    cilium_bgp_secret           = var.cilium_bgp_secret
    cilium_bgp_port             = var.cilium_bgp_port
    cilium_lb_svc_cidr          = var.cilium_lb_svc_cidr
  })
}

output "kubeconfig" {
  description = "Kubernetes client configuration and raw kubeconfig"
  sensitive   = true
  value = {
    raw                    = talos_cluster_kubeconfig.this.kubeconfig_raw
    host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
    client_certificate     = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate
    client_key             = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key
    cluster_ca_certificate = talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate
  }
}

output "talosconfig" {
  description = "Talosconfig for the Talos cluster"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}
