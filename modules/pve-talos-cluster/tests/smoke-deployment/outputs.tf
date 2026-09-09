output "http_backend_response" {
  description = "The response received through the LoadBalancer external IP."
  value       = data.http.load_balancer.response_body
}

output "load_balancer_ip" {
  description = "The external IP assigned to the smoke-test LoadBalancer service."
  value       = try(kubernetes_service_v1.smoke.status[0].load_balancer[0].ingress[0].ip, null)
}
