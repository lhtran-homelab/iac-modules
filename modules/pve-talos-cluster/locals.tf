locals {
  talos_version    = "v${var.talos_version}"
  cluster_endpoint = "https://${var.talos_cluster_virtual_ip_hostname}:6443"

  sa_s3_oidc_enabled = var.sa_s3_oidc != null
  oidc_region        = try(var.sa_s3_oidc.region, "us-east-1")
  oidc_bucket        = "oidc-${join("", data.aws_caller_identity.current[*].account_id)}-${var.talos_cluster_name}"
  oidc_issuer        = local.sa_s3_oidc_enabled ? "https://${local.oidc_bucket}.s3.${local.oidc_region}.amazonaws.com" : local.cluster_endpoint
  oidc_jwks_uri      = "${local.oidc_issuer}/openid/v1/jwks"
  sa_s3_oidc_args = merge(
    {
      anonymous-auth           = "true"
      service-account-issuer   = local.oidc_issuer
      service-account-jwks-uri = local.oidc_jwks_uri
    },
    local.sa_s3_oidc_enabled ? {
      api-audiences = join(",", [local.oidc_issuer, local.cluster_endpoint])
    } : {}
  )

  idp_oidc_enabled = var.idp_oidc != null
  idp_oidc_args = local.idp_oidc_enabled ? merge(
    {
      oidc-issuer-url     = var.idp_oidc.issuer_url
      oidc-client-id      = var.idp_oidc.client_id
      oidc-username-claim = var.idp_oidc.username_claim
      oidc-groups-claim   = var.idp_oidc.groups_claim
      oidc-groups-prefix  = var.idp_oidc.groups_prefix
    },
    var.idp_oidc.client_secret != null && var.idp_oidc.client_secret != "" ? {
      oidc-client-secret = var.idp_oidc.client_secret
    } : {}
  ) : {}

  apiserver_extra_args = merge(
    local.sa_s3_oidc_args,
    local.idp_oidc_args
  )

  idp_oidc_rbac = local.idp_oidc_enabled && length(var.idp_oidc.cluster_admin_groups) > 0 ? yamlencode({
    apiVersion = "rbac.authorization.k8s.io/v1"
    kind       = "ClusterRoleBinding"
    metadata = {
      name = "oidc-cluster-admins"
    }
    roleRef = {
      apiGroup = "rbac.authorization.k8s.io"
      kind     = "ClusterRole"
      name     = "cluster-admin"
    }
    subjects = [
      for group in var.idp_oidc.cluster_admin_groups : {
        apiGroup = "rbac.authorization.k8s.io"
        kind     = "Group"
        name     = "${var.idp_oidc.groups_prefix}${group}"
      }
    ]
  }) : ""

  inline_manifests = concat(
    [
      {
        name     = "gateway-api-crds"
        contents = data.http.gateway_api_crds.response_body
      },
      {
        name     = "allow-anonymous-jwks-discovery"
        contents = <<-YAML
          apiVersion: rbac.authorization.k8s.io/v1
          kind: ClusterRoleBinding
          metadata:
            name: allow-anonymous-jwks-discovery
          subjects:
            - kind: Group
              name: system:unauthenticated
              apiGroup: rbac.authorization.k8s.io
          roleRef:
            kind: ClusterRole
            name: system:service-account-issuer-discovery
            apiGroup: rbac.authorization.k8s.io
        YAML
      },
      {
        name     = "namespaces"
        contents = file("${path.module}/talos_inline/namespaces.yml")
      },
      {
        name = "infra-secrets"
        contents = templatefile("${path.module}/talos_inline/secrets.yml", {
          cilium_bgp_secret                                                 = var.cilium_bgp_secret
          democratic_csi_truenas_api_protocol                               = var.democratic_csi_truenas_api_protocol
          democratic_csi_truenas_host                                       = var.democratic_csi_truenas_host
          democratic_csi_truenas_api_port                                   = var.democratic_csi_truenas_api_port
          democratic_csi_truenas_api_key                                    = var.democratic_csi_truenas_api_key
          democratic_csi_truenas_zfs_dataset_parent_name                    = var.democratic_csi_truenas_zfs_dataset_parent_name
          democratic_csi_truenas_zfs_detached_snapshots_dataset_parent_name = var.democratic_csi_truenas_zfs_detached_snapshots_dataset_parent_name
          democratic_csi_truenas_nvmeof_port                                = var.democratic_csi_truenas_nvmeof_port
          democratic_csi_truenas_nvmeof_port_index                          = var.democratic_csi_truenas_nvmeof_port_index
        })
      }
    ],
    local.idp_oidc_rbac != "" ? [
      {
        name     = "oidc-cluster-admins"
        contents = local.idp_oidc_rbac
      }
    ] : []
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
