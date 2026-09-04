terraform {
  required_version = "~> 1.10"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.93"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.10"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    pihole = {
      source  = "ryanwholey/pihole"
      version = "2.0.0-beta.1"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.6"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_api_token_id}=${var.proxmox_api_token_secret}"

  # ssh is used for proxmox_virtual_environment_vm
  ssh {
    agent       = true
    username    = var.proxmox_ssh_user
    private_key = var.proxmox_ssh_private_key
  }
}

provider "helm" {
  kubernetes = {
    host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
    client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
    client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
    cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
  }
}

provider "pihole" {
  url      = var.pihole_url
  password = var.pihole_password
}

provider "aws" {
  region = "us-east-1"
}

