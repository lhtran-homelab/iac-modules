# This block defines variables specifically for the test run
variables {
  proxmox_nodes        = ["pve2"]

  vm_storage                          = "truenas-nvme"
  vm_image_storage                    = "truenas-nfs"
  vm_image_randomize_file_name        = true
  vm_network_pve_bridge               = "vmbr100"
  vm_network_subnet                   = "172.16.100.0/24"
  vm_network_gateway                  = "172.16.100.1"
  vm_network_first_controller_hostnum = 231
  vm_network_first_worker_hostnum     = 232

  vm_controller_count        = 1
  vm_controller_cpu_cores    = 2
  vm_controller_memory       = 2048
  vm_controller_disk_size_gb = 40

  vm_worker_count        = 1
  vm_worker_cpu_cores    = 2
  vm_worker_memory       = 2048
  vm_worker_disk_size_gb = 40

  talos_cluster_name     = "e2e-tftest"
  talos_cluster_virtual_ip_hostname = "e2e-tftest.lhtran.com"
  talos_cluster_virtual_ip          = "172.16.100.230"
  talos_architecture     = "amd64"
  talos_version          = "1.13.8"
  talos_schematic_id     = "e15f3b626ab4a557519983f80f0530ab962ceb961e49c38f577da35dfeee9fa4" #siderolabs/iscsi-tools, siderolabs/nfs-utils, siderolabs/nvme-cli, siderolabs/qemu-guest-agent
  kubernetes_version     = "1.36.2"
  kubernetes_api_gateway = {
    version = "1.6.1"
    channel = "standard"
  }
  kubernetes_pods_cidr  = "10.240.0.0/16"
  helm_cilium_version   = "1.20.0"
  cilium_bgp_port       = 1790
  cilium_lb_svc_cidr    = "10.200.254.0/24"
  cilium_bgp_local_asn  = 65000
  cilium_bgp_remote_asn = 65100

  helm_democratic_csi_version                                       = "0.15.1"
  democratic_csi_truenas_zfs_dataset_parent_name                    = "RAIDZ1-SSD/TALOS-NVME/vols"
  democratic_csi_truenas_zfs_detached_snapshots_dataset_parent_name = "RAIDZ1-SSD/TALOS-NVME/snaps"
}

run "create_cluster" {
  command = apply

  assert {
    condition     = output.kubeconfig != null
    error_message = "Kubeconfig was not generated."
  }
}

provider "kubernetes" {
  alias = "smoke"
  host = yamldecode(run.create_cluster.kubeconfig).clusters[0].cluster.server
  cluster_ca_certificate = base64decode(yamldecode(run.create_cluster.kubeconfig).clusters[0].cluster["certificate-authority-data"])
  client_certificate = base64decode(yamldecode(run.create_cluster.kubeconfig).users[0].user["client-certificate-data"])
  client_key = base64decode(yamldecode(run.create_cluster.kubeconfig).users[0].user["client-key-data"])
}

run "run_smoke_pod" {
  command = apply

  module {
    source = "./tests/smoke-pod"
  }

  providers = {
    kubernetes = kubernetes.smoke
  }

  assert {
    condition     = output.completed
    error_message = "The Kubernetes storage smoke test did not complete."
  }
}
