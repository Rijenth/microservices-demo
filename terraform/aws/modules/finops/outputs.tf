output "sns_topic_arn" {
  description = "ARN du topic SNS centralisé pour toutes les alertes de coûts"
  value       = aws_sns_topic.cost_alerts.arn
}

output "resource_group_arn" {
  description = "ARN du Resource Group — utiliser dans AWS Cost Explorer pour filtrer par projet"
  value       = aws_resourcegroups_group.project.arn
}

output "anomaly_monitor_arn" {
  description = "ARN du moniteur AWS Cost Anomaly Detection (vide si désactivé)"
  value       = var.enable_anomaly_detection ? aws_ce_anomaly_monitor.project[0].arn : null
}

output "cloudwatch_dashboard_url" {
  description = "URL du dashboard CloudWatch FinOps"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.finops.dashboard_name}"
}
