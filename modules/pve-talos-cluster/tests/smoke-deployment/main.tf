resource "kubernetes_deployment_v1" "load_balancer_backend" {
  metadata {
    name      = "terraform-e2e-load-balancer"
    namespace = "default"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "terraform-e2e-load-balancer"
      }
    }

    template {
      metadata {
        labels = {
          app = "terraform-e2e-load-balancer"
        }
      }

      spec {
        container {
          name  = "http"
          image = "busybox:1.36.1"

          command = ["/bin/sh", "-ec", "mkdir -p /www; printf '%s' terraform-e2e-load-balancer > /data/index.html; ln -s /data/index.html /www/index.html; httpd -f -p 8080 -h /www"]

          volume_mount {
            name       = "smoke-storage"
            mount_path = "/data"
          }

          port {
            container_port = 8080
          }
        }

        volume {
          name = "smoke-storage"

          ephemeral {
            volume_claim_template {
              spec {
                access_modes       = ["ReadWriteOnce"]
                storage_class_name = "freenas-api-nvmeof"
                volume_mode        = "Filesystem"

                resources {
                  requests = {
                    storage = "1Gi"
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "smoke" {
  depends_on = [kubernetes_deployment_v1.load_balancer_backend]

  metadata {
    name      = "terraform-e2e-smoke"
    namespace = "default"
  }

  spec {
    selector = {
      app = "terraform-e2e-load-balancer"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "LoadBalancer"
  }

  wait_for_load_balancer = true

  timeouts {
    create = "5m"
  }
}

data "http" "load_balancer" {
  url        = "http://${kubernetes_service_v1.smoke.status[0].load_balancer[0].ingress[0].ip}/"
  depends_on = [kubernetes_service_v1.smoke]

  retry {
    attempts     = 10
    min_delay_ms = 1000
    max_delay_ms = 5000
  }
}
