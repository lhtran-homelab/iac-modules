locals {
  talos_version    = "v${var.talos_version}"
  cluster_endpoint = "https://${var.talos_cluster_virtual_ip_hostname}:6443"
  controller_nodes = [
    for i in range(var.vm_controller_count) : {
      name    = "${var.talos_cluster_name}-controller-${i + 1}"
      address = "${cidrhost(var.vm_network_subnet, var.vm_network_first_controller_hostnum + i)}/${split("/", var.vm_network_subnet)[1]}"

    }
  ]
  worker_nodes = [
    for i in range(var.vm_worker_count) : {
      name    = "${var.talos_cluster_name}-worker-${i + 1}"
      address = "${cidrhost(var.vm_network_subnet, var.vm_network_first_worker_hostnum + i)}/${split("/", var.vm_network_subnet)[1]}"
    }
  ]
  kube_prism_port = 7445
  common_machine_configs = [
    {
      machine = {
        install = {
          disk = "/dev/vda"
        }
        features = {
          kubePrism = {
            enabled = true
            port    = local.kube_prism_port
          }
        }
      }
      cluster = {
        network = {
          cni = {
            name = "none"
          }
          podSubnets = [
            var.kubernetes_pods_cidr
          ]
        }
        proxy = {
          disabled = true
        }
      }
    }
  ]
}
