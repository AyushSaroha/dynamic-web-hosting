output "ec2_public_ip" {
  description = "Elastic public IP address for the EC2 server"
  value       = aws_eip.dynamic_site.public_ip
}

output "website_url" {
  description = "Website URL"
  value       = "http://${aws_eip.dynamic_site.public_ip}"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${aws_eip.dynamic_site.public_ip}:3000"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_eip.dynamic_site.public_ip}:9090"
}
