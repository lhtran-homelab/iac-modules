output "completed" {
  description = "Whether the smoke-test Job completed successfully."
  value       = kubernetes_job_v1.smoke.id != ""
}
