resource "helm_release" "democratic_csi" {
  depends_on       = [data.talos_cluster_health.this]
  namespace        = "democratic-csi"
  name             = "democratic-csi"
  repository       = "https://democratic-csi.github.io/charts"
  chart            = "democratic-csi"
  create_namespace = false
  version          = var.helm_democratic_csi_version
  values = [
    file("${path.module}/helm_values/democratic-csi.yml")
  ]
}