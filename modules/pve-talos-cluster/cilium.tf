resource "helm_release" "cilium" {
  namespace        = "kube-system"
  name             = "cilium"
  repository       = "https://helm.cilium.io"
  chart            = "cilium"
  create_namespace = false
  version          = var.helm_cilium_version
  values = [
    templatefile("${path.module}/helm_values/cilium.yml", {
      kube_prism_port = local.kube_prism_port
      pods_cidr       = var.kubernetes_pods_cidr
    })
  ]
  depends_on = [talos_machine_bootstrap.this, null_resource.wait_for_kube_apiserver]
}

resource "helm_release" "cilium_config" {
  depends_on       = [data.talos_cluster_health.this, null_resource.wait_for_cilium_crds]
  namespace        = "kube-system"
  name             = "cilium-config"
  chart            = "${path.module}/charts/cilium-config"
  create_namespace = false

  values = [
    templatefile("${path.module}/helm_values/cilium_config.yml", {
      cilium_lb_svc_cidr    = var.cilium_lb_svc_cidr
      cilium_bgp_local_asn  = var.cilium_bgp_local_asn
      cilium_bgp_port       = var.cilium_bgp_port
      cilium_bgp_remote_asn = var.cilium_bgp_remote_asn
    })
  ]
}