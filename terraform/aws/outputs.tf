output "frontend_url" {
  description = "URL to access the Online Boutique frontend (via ALB)"
  value       = "http://${module.alb.alb_dns_name}"
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = module.ec2.public_ip
}

output "db_private_ip" {
  description = "Private IP of the database EC2 instance"
  value       = module.rds.private_ip
}

output "grafana_url" {
  description = "Grafana URL (available ~2min after apply)"
  value       = module.grafana.grafana_url
}

output "grafana_public_ip" {
  description = "Public IP of the Grafana EC2 instance"
  value       = module.grafana.public_ip
}

output "finops_sns_topic_arn" {
  description = "ARN du topic SNS pour les alertes de coûts"
  value       = module.finops.sns_topic_arn
}

output "finops_dashboard_url" {
  description = "URL du dashboard CloudWatch FinOps"
  value       = module.finops.cloudwatch_dashboard_url
}

output "finops_resource_group_arn" {
  description = "ARN du Resource Group — filtrer les coûts par projet dans Cost Explorer"
  value       = module.finops.resource_group_arn
}
