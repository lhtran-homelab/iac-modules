output "frr_bgp_config" {
  description = "Rendered FRR BGP configuration"
  sensitive   = true
  value = templatefile("${path.module}/templates/frr-bgp.conf.tmpl", {
    cilium_bgp_remote_asn       = var.cilium_bgp_remote_asn
    cilium_bgp_remote_router_id = var.cilium_bgp_remote_router_id
    cilium_bgp_local_asn        = var.cilium_bgp_local_asn
    cilium_bgp_secret           = var.cilium_bgp_secret
    cilium_bgp_port             = var.cilium_bgp_port
    cluster_node_network        = var.vm_network_subnet
    cilium_lb_svc_cidr          = var.cilium_lb_svc_cidr
  })
}

output "kubeconfig" {
  description = "Kubeconfig for the Talos Kubernetes cluster"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "talosconfig" {
  description = "Talosconfig for the Talos cluster"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}