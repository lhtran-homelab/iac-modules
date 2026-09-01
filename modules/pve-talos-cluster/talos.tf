data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v${var.kubernetes_api_gateway.version}/${var.kubernetes_api_gateway.channel}-install.yaml"
}

resource "talos_machine_secrets" "this" {
  talos_version = local.talos_version
}

data "talos_machine_configuration" "controller" {
  cluster_name       = var.talos_cluster_name
  machine_type       = "controlplane"
  talos_version      = local.talos_version
  kubernetes_version = var.kubernetes_version
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches = concat(
    [for c in local.common_machine_configs : yamlencode(c)],
    [yamlencode({
      apiVersion = "v1alpha1"
      kind       = "Layer2VIPConfig"
      name       = var.talos_cluster_virtual_ip
      link       = local.controller_nodes[0].interface
    })],
    [yamlencode({
      cluster = {
        apiServer = {
          extraArgs = {
            anonymous-auth           = "true"
            service-account-jwks-uri = "${local.cluster_endpoint}/openid/v1/jwks"
          }
        }
        inlineManifests = [
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
        ]
      }
    })],
  )
}

data "talos_machine_configuration" "worker" {
  cluster_name       = var.talos_cluster_name
  machine_type       = "worker"
  talos_version      = local.talos_version
  kubernetes_version = var.kubernetes_version
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches     = [for c in local.common_machine_configs : yamlencode(c)]
}

resource "talos_machine_configuration_apply" "controller" {
  count                       = var.vm_controller_count
  machine_configuration_input = data.talos_machine_configuration.controller.machine_configuration
  node                        = local.controller_nodes[count.index].ipv4
  client_configuration        = talos_machine_secrets.this.client_configuration
  apply_mode                  = "auto"
  depends_on                  = [proxmox_virtual_environment_vm.talos-controller]
  lifecycle {
    replace_triggered_by = [
      proxmox_virtual_environment_vm.talos-controller[count.index]
    ]
  }
}

resource "talos_machine_configuration_apply" "worker" {
  count                       = var.vm_worker_count
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = local.worker_nodes[count.index].ipv4
  client_configuration        = talos_machine_secrets.this.client_configuration
  depends_on                  = [proxmox_virtual_environment_vm.talos-worker]
  lifecycle {
    replace_triggered_by = [
      proxmox_virtual_environment_vm.talos-worker[count.index]
    ]
  }
}

resource "talos_machine_bootstrap" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.controller_nodes[0].ipv4
  depends_on = [
    talos_machine_configuration_apply.controller,
    talos_machine_configuration_apply.worker
  ]
}

resource "null_resource" "wait_for_kube_apiserver" {
  triggers = {
    bootstrap = talos_machine_bootstrap.this.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      for i in $(seq 1 60); do
        if curl -k -s -o /dev/null --max-time 5 "${talos_cluster_kubeconfig.this.kubernetes_client_configuration.host}/version"; then
          echo "kube-apiserver is ready"
          exit 0
        fi
        sleep 5
      done
      echo "Timed out waiting for kube-apiserver"
      exit 1
    EOT
  }

  depends_on = [talos_machine_bootstrap.this, talos_cluster_kubeconfig.this, pihole_dns_record.record]
}

data "talos_cluster_health" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  control_plane_nodes  = [for node in local.controller_nodes : node.ipv4]
  worker_nodes         = [for node in local.worker_nodes : node.ipv4]
  endpoints            = [for node in local.controller_nodes : node.ipv4]
  timeouts = {
    read = "5m"
  }
  depends_on = [talos_machine_bootstrap.this, helm_release.cilium]
}

resource "talos_cluster_kubeconfig" "this" {
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.controller_nodes[0].ipv4
  depends_on = [talos_machine_bootstrap.this]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.talos_cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for node in local.controller_nodes : node.ipv4]
}

resource "null_resource" "wait_for_cilium_crds" {
  triggers = {
    cilium = helm_release.cilium.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -eu

      if ! command -v curl >/dev/null 2>&1; then
        echo "curl is required but was not found on PATH" >&2
        exit 127
      fi

      tmpdir=$(mktemp -d)
      trap 'rm -rf "$tmpdir"' EXIT
      umask 077

      cat <<'CERT' > "$tmpdir/ca.crt"
      ${base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)}
      CERT
      cat <<'CERT' > "$tmpdir/client.crt"
      ${base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)}
      CERT
      cat <<'CERT' > "$tmpdir/client.key"
      ${base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)}
      CERT

      api_url="${talos_cluster_kubeconfig.this.kubernetes_client_configuration.host}/apis/cilium.io/v2/ciliumloadbalancerippools?limit=1"
      echo "Waiting for the CiliumLoadBalancerIPPool API to become available"

      for i in $(seq 1 60); do
        if curl \
          --fail \
          --silent \
          --connect-timeout 5 \
          --max-time 10 \
          --cacert "$tmpdir/ca.crt" \
          --cert "$tmpdir/client.crt" \
          --key "$tmpdir/client.key" \
          --output /dev/null \
          "$api_url"; then
          echo "CiliumLoadBalancerIPPool API is available"
          exit 0
        fi

        sleep 5
      done

      echo "Timed out waiting for the CiliumLoadBalancerIPPool API" >&2
      exit 1
    EOT
  }

  depends_on = [helm_release.cilium, talos_cluster_kubeconfig.this]
}
