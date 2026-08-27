variable "proxmox_api_url" {
  type        = string
  description = "The URL for the Proxmox API."
}

variable "proxmox_api_token_id" {
  type        = string
  description = "The Proxmox API token ID."
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  type        = string
  description = "The Proxmox API token secret."
  sensitive   = true
}

# variable "proxmox_ssh_host" {
#   description = "The hostname or IP address of the Proxmox node for SSH."
#   type        = string
# }

variable "proxmox_ssh_user" {
  description = "The username for SSH access to the Proxmox node."
  type        = string
  default     = "root"
}

variable "proxmox_ssh_private_key" {
  description = "The private SSH key for accessing the Proxmox node."
  type        = string
  sensitive   = true
}

variable "proxmox_nodes" {
  type        = list(string)
  description = "A list of Proxmox nodes to create the VMs on."
}

variable "vm_storage" {
  type        = string
  description = "The Proxmox storage for the VM disks."
}

variable "vm_image_storage" {
  type        = string
  description = "The Proxmox storage for the ISO files."
}

variable "vm_network_gateway" {
  description = "The IP network gateway of the cluster nodes"
  type        = string
}

variable "vm_network_subnet" {
  description = "The network of the cluster nodes"
  type        = string
}

variable "vm_network_pve_bridge" {
  type        = string
  description = "The network bridge for the VMs."
  default     = "vmbr0"
}

variable "vm_network_first_controller_hostnum" {
  description = "The hostnum of the first controller host"
  type        = number
}

variable "vm_network_first_worker_hostnum" {
  description = "The hostnum of the first worker host"
  type        = number
}

variable "vm_controller_count" {
  type        = number
  description = "The number of controller VMs to create."
  default     = 1
}

variable "vm_worker_count" {
  type        = number
  description = "The number of worker VMs to create."
  default     = 1
}

variable "vm_controller_memory" {
  type        = number
  description = "The memory for each controller VM in MB."
  default     = 4096
}

variable "vm_controller_cpu_cores" {
  type        = number
  description = "The number of CPU cores for each controller VM."
  default     = 2
}

variable "vm_controller_disk_size_gb" {
  type        = string
  description = "The disk size for each controller VM."
  default     = "40"
}

variable "vm_worker_memory" {
  type        = number
  description = "The memory for each worker VM in MB."
  default     = 4096
}

variable "vm_worker_cpu_cores" {
  type        = number
  description = "The number of CPU cores for each worker VM."
  default     = 2
}

variable "vm_worker_disk_size_gb" {
  type        = string
  description = "The disk size for each worker VM."
  default     = "60"
}

variable "talos_schematic_id" {
  type        = string
  description = "The Talos schematic id to use."
  default     = "ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515"
}

variable "talos_version" {
  type        = string
  description = "The version of Talos to use."
  default     = "1.12.2"
}

variable "talos_architecture" {
  type        = string
  description = "The architecture of Talos to use."
  default     = "amd64"
}

variable "talos_image_randomize_file_name" {
  type        = bool
  description = "Whether to append a stable random suffix to the Talos image filename."
  default     = true
}

variable "kubernetes_version" {
  type        = string
  description = "The version of Kubernetes to use."
  default     = "1.30.0"
}

variable "talos_cluster_name" {
  type        = string
  description = "The name of the Talos cluster."
}

variable "talos_cluster_virtual_ip_hostname" {
  type        = string
  description = "The hostname for the Talos cluster virtual IP. This is used for the Talos API and Kubernetes API."
}

variable "talos_cluster_virtual_ip" {
  type        = string
  description = "The virtual IP for the Talos cluster. This is used for the Talos API and Kubernetes API."
}

variable "kubernetes_api_gateway" {
  description = "Gateway API CRD installation settings."

  type = object({
    version = string
    channel = string
  })

  default = {
    version = "1.6.1"
    channel = "standard"
  }

  validation {
    condition     = contains(["standard", "experimental"], var.kubernetes_api_gateway.channel)
    error_message = "channel must be either standard or experimental."
  }
}

variable "kubernetes_pods_cidr" {
  type        = string
  description = "The CIDR for the pods network."
  default     = "10.244.0.0/16"
}

variable "helm_cilium_version" {
  type        = string
  description = "The version of the Cilium Helm chart to use."
  default     = "1.18.6"
}

variable "cilium_bgp_port" {
  type        = number
  description = "The port to use for Cilium BGP."
  default     = 1790
}

variable "cilium_bgp_local_asn" {
  type        = number
  description = "The local ASN to use for BGP."
  default     = 65000
}

variable "cilium_bgp_remote_asn" {
  type        = number
  description = "The remote ASN to use for BGP."
  default     = 65100
}

variable "cilium_bgp_remote_router_id" {
  type        = string
  description = "The router ID for the remote BGP peer."
  default     = "192.168.1.1"
}

variable "cilium_lb_svc_cidr" {
  type        = string
  description = "The external IP range to use for the load balancer service."
  default     = "10.200.1.0/24"
}

variable "cilium_bgp_secret" {
  type        = string
  description = "The secret to use for the BGP authentication."
  sensitive   = true
}

variable "helm_democratic_csi_version" {
  type        = string
  description = "The version of the Democratic CSI Helm chart to use."
  default     = "0.15.1"
}

variable "democratic_csi_truenas_api_protocol" {
  type        = string
  description = "The protocol to use for the TrueNAS API."
  default     = "https"
}

variable "democratic_csi_truenas_host" {
  type        = string
  description = "The hostname or IP address of the TrueNAS server."
}

variable "democratic_csi_truenas_api_port" {
  type        = number
  description = "The port to use for the TrueNAS API."
  default     = 443
}

variable "democratic_csi_truenas_api_key" {
  type        = string
  description = "The API key to use for the TrueNAS API."
  sensitive   = true
}

variable "democratic_csi_truenas_zfs_dataset_parent_name" {
  type        = string
  description = "The parent dataset name to use for the TrueNAS ZFS datasets."
}

variable "democratic_csi_truenas_zfs_detached_snapshots_dataset_parent_name" {
  type        = string
  description = "The parent dataset name to use for the TrueNAS detached snapshots ZFS datasets."
}

variable "democratic_csi_truenas_nvmeof_port" {
  type        = number
  description = "The port to use for the TrueNAS NVMe-oF."
  default     = 4420
}

variable "democratic_csi_truenas_nvmeof_port_index" {
  type        = number
  description = "The port index to use for the TrueNAS NVMe-oF."
  default     = 1
}

variable "pihole_url" {
  type        = string
  description = "The URL for the Pi-hole instance."
}

variable "pihole_password" {
  type        = string
  description = "The password for the Pi-hole instance."
  sensitive   = true
}
