output "instance_id" {
  description = "Grafana EC2 instance ID"
  value       = aws_instance.grafana.id
}

output "public_ip" {
  description = "Public IP of the Grafana instance"
  value       = aws_instance.grafana.public_ip
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${aws_instance.grafana.public_ip}:3000"
}
