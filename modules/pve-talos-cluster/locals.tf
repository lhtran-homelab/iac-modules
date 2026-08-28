locals {
  talos_version    = "v${var.talos_version}"
  cluster_endpoint = "https://${var.talos_cluster_virtual_ip_hostname}:6443"
  controller_node_names = [
    for i in range(var.vm_controller_count) : "${var.talos_cluster_name}-controller-${i + 1}"
  ]
  worker_node_names = [
    for i in range(var.vm_worker_count) : "${var.talos_cluster_name}-worker-${i + 1}"
  ]
  controller_nodes = [
    for vm_i, vm in proxmox_virtual_environment_vm.talos-controller : one([
      for mac_i, mac in vm.mac_addresses : {
        name            = vm.name
        interface_index = mac_i
        interface       = vm.network_interface_names[mac_i]
        ipv4            = vm.ipv4_addresses[mac_i][0]
      } if lower(mac) == lower(vm.network_device[0].mac_address)
    ])
  ]
  worker_nodes = [
    for vm_i, vm in proxmox_virtual_environment_vm.talos-worker : one([
      for mac_i, mac in vm.mac_addresses : {
        name            = vm.name
        interface_index = mac_i
        interface       = vm.network_interface_names[mac_i]
        ipv4            = vm.ipv4_addresses[mac_i][0]
      } if lower(mac) == lower(vm.network_device[0].mac_address)
    ])
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
