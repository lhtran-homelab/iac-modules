resource "pihole_dns_record" "record" {
  domain = var.talos_cluster_virtual_ip_hostname
  ip     = var.talos_cluster_virtual_ip
}