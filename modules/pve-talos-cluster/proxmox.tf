resource "random_id" "talos_image_suffix" {
  count       = var.talos_image_randomize_file_name ? 1 : 0
  byte_length = 4

  keepers = {
    architecture  = var.talos_architecture
    schematic_id  = var.talos_schematic_id
    talos_version = local.talos_version
  }
}

resource "proxmox_download_file" "talos_image" {
  content_type = "iso"
  datastore_id = var.vm_image_storage
  node_name    = var.proxmox_nodes[0]

  url                     = "https://factory.talos.dev/image/${var.talos_schematic_id}/${local.talos_version}/nocloud-${var.talos_architecture}.raw.xz"
  decompression_algorithm = "zst"
  overwrite               = false
  file_name = join("", [
    "talos-${local.talos_version}-nocloud-${var.talos_architecture}",
    var.talos_image_randomize_file_name ? "-${random_id.talos_image_suffix[0].hex}" : "",
    ".raw.img",
  ])

  lifecycle {
    ignore_changes = [
      node_name,
    ]
  }
}

resource "proxmox_virtual_environment_vm" "talos-controller" {
  count = var.vm_controller_count

  name        = local.controller_node_names[count.index]
  description = "Managed by Terraform  \nCluster: ${var.talos_cluster_name}  \nName: controller ${local.controller_node_names[count.index]}"
  tags        = ["terraform", "talos"]
  node_name   = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]

  machine    = "q35"
  bios       = "ovmf"
  boot_order = ["virtio0"]

  cpu {
    cores = var.vm_controller_cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.vm_controller_memory
    floating  = 0
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = var.vm_storage
    size         = var.vm_controller_disk_size_gb
    file_id      = proxmox_download_file.talos_image.id
    file_format  = "raw"
    discard      = "on"
    iothread     = true
    interface    = "virtio0"
  }

  efi_disk {
    datastore_id = var.vm_storage
    type         = "4m"
    file_format  = "raw"
  }

  network_device {
    model  = "virtio"
    bridge = var.vm_network_pve_bridge
  }

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
    trim    = true
  }

  initialization {
    datastore_id = var.vm_storage
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      node_name,
    ]
  }
}


resource "proxmox_virtual_environment_vm" "talos-worker" {
  count = var.vm_worker_count

  name        = local.worker_node_names[count.index]
  description = "Managed by Terraform  \nCluster: ${var.talos_cluster_name}  \nName: worker ${local.worker_node_names[count.index]}"
  tags        = ["terraform", "talos"]
  node_name   = var.proxmox_nodes[count.index % length(var.proxmox_nodes)]

  machine = "q35"
  bios    = "ovmf"

  cpu {
    cores = var.vm_worker_cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.vm_worker_memory
    floating  = 0
  }

  scsi_hardware = "virtio-scsi-single"

  disk {
    datastore_id = var.vm_storage
    size         = var.vm_worker_disk_size_gb
    file_id      = proxmox_download_file.talos_image.id
    file_format  = "raw"
    discard      = "on"
    iothread     = true
    interface    = "virtio0"
  }

  efi_disk {
    datastore_id = var.vm_storage
    type         = "4m"
    file_format  = "raw"
  }

  network_device {
    model  = "virtio"
    bridge = var.vm_network_pve_bridge
  }

  operating_system {
    type = "l26"
  }

  agent {
    enabled = true
    trim    = true
  }

  initialization {
    datastore_id = var.vm_storage
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  lifecycle {
    ignore_changes = [
      node_name,
    ]
  }
}
