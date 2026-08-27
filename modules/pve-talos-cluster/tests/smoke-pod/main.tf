resource "kubernetes_job_v1" "smoke" {
  metadata {
    name      = "terraform-e2e-smoke"
    namespace = "default"
  }

  wait_for_completion = true

  spec {
    backoff_limit = 0

    template {
      metadata {
        labels = {
          app = "terraform-e2e-smoke"
        }
      }

      spec {
        restart_policy = "Never"

        container {
          name  = "smoke"
          image = "busybox:1.36.1"

          command = [
            "/bin/sh",
            "-ec",
            <<-EOT
              nslookup kubernetes.default.svc.cluster.local
              probe="terraform-e2e-storage-$(date +%s)"
              printf '%s' "$${probe}" > /data/probe
              test "$(cat /data/probe)" = "$${probe}"
              sync
            EOT
          ]

          volume_mount {
            name       = "smoke-storage"
            mount_path = "/data"
          }
        }

        volume {
          name = "smoke-storage"

          ephemeral {
            volume_claim_template {
              metadata {
                labels = {
                  app = "terraform-e2e-smoke"
                }
              }

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

  timeouts {
    create = "5m"
    delete = "5m"
  }
}
