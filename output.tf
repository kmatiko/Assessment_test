output dns_loadbalancer {
  value       = aws_lb.load_balancer.dns_name
  description = "DNS name of LoadBalancer"

}
