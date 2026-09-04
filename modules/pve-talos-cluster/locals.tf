locals {
  talos_version    = "v${var.talos_version}"
  cluster_endpoint = "https://${var.talos_cluster_virtual_ip_hostname}:6443"

  s3_oidc_enabled = var.s3_oidc != null
  oidc_region     = try(var.s3_oidc.region, "us-east-1")
  oidc_bucket     = "oidc-${join("", data.aws_caller_identity.current[*].account_id)}-${var.talos_cluster_name}"
  oidc_issuer     = local.s3_oidc_enabled ? "https://${local.oidc_bucket}.s3.${local.oidc_region}.amazonaws.com" : local.cluster_endpoint
  oidc_jwks_uri   = "${local.oidc_issuer}/openid/v1/jwks"

  apiserver_extra_args = merge(
    {
      anonymous-auth           = "true"
      service-account-issuer   = local.oidc_issuer
      service-account-jwks-uri = local.oidc_jwks_uri
    },
    local.s3_oidc_enabled ? {
      api-audiences = join(",", [local.oidc_issuer, local.cluster_endpoint])
    } : {}
  )
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
