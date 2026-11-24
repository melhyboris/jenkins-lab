terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

variable "kubeconfig" {
  type = string
}

variable "message" {
  type    = string
  default = "Hello from Terraform"
}

provider "kubernetes" {
  config_path    = var.kubeconfig
  config_context = "kind-lab"
}

resource "kubernetes_namespace_v1" "lab" {
  metadata {
    name   = "hcl-lab"
    labels = { "managed-by" = "terraform" }
  }
}

resource "kubernetes_resource_quota_v1" "lab" {
  metadata {
    name      = "lab-quota"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }
  spec {
    hard = {
      pods              = "10"
      "requests.cpu"    = "1"
      "requests.memory" = "1Gi"
      "limits.memory"   = "2Gi"
    }
  }
}

resource "kubernetes_config_map_v1" "hello" {
  metadata {
    name      = "hello-config"
    namespace = kubernetes_namespace_v1.lab.metadata[0].name
  }
  data = {
    MESSAGE = var.message
  }
}

output "namespace" {
  value = kubernetes_namespace_v1.lab.metadata[0].name
}
