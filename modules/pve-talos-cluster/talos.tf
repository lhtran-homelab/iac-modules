data "http" "gateway_api_crds" {
  url = "https://github.com/kubernetes-sigs/gateway-api/releases/download/v${var.kubernetes_api_gateway.version}/${var.kubernetes_api_gateway.channel}-install.yaml"
}

resource "talos_machine_secrets" "this" {
  talos_version = local.talos_version
}

data "talos_machine_configuration" "controller" {
  count              = var.vm_controller_count
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
          extraArgs = local.apiserver_extra_args
        }
        inlineManifests = local.inline_manifests
      }
    })],
    [yamlencode({
      machine = {
        nodeLabels = {
          "proxmox.com/nodename" = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
        }
      }
    })]
  )
}

data "talos_machine_configuration" "worker" {
  count              = var.vm_worker_count
  cluster_name       = var.talos_cluster_name
  machine_type       = "worker"
  talos_version      = local.talos_version
  kubernetes_version = var.kubernetes_version
  cluster_endpoint   = local.cluster_endpoint
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches = concat(
    [for c in local.common_machine_configs : yamlencode(c)],
    [yamlencode({
      machine = {
        nodeLabels = {
          "proxmox.com/nodename" = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]
        }
      }
    })]
  )
}

resource "talos_machine_configuration_apply" "controller" {
  count                       = var.vm_controller_count
  machine_configuration_input = data.talos_machine_configuration.controller[count.index].machine_configuration
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
  machine_configuration_input = data.talos_machine_configuration.worker[count.index].machine_configuration
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
    command = templatefile("${path.module}/templates/wait-for-url.sh.tmpl", {
      ca_cert_pem      = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
      client_cert_pem  = ""
      client_key_pem   = ""
      url              = "${talos_cluster_kubeconfig.this.kubernetes_client_configuration.host}/version"
      expected_status  = "200"
      attempts         = 10
      interval_seconds = 5
      description      = "Waiting for the kube-apiserver to become ready"
    })
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
  depends_on           = [talos_machine_bootstrap.this]
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
    command = templatefile("${path.module}/templates/wait-for-url.sh.tmpl", {
      ca_cert_pem      = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
      client_cert_pem  = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
      client_key_pem   = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
      url              = "${talos_cluster_kubeconfig.this.kubernetes_client_configuration.host}/apis/cilium.io/v2/ciliumloadbalancerippools?limit=1"
      expected_status  = "200"
      attempts         = 10
      interval_seconds = 5
      description      = "Waiting for the CiliumLoadBalancerIPPool API to become available"
    })
  }

  depends_on = [helm_release.cilium, talos_cluster_kubeconfig.this]
}
