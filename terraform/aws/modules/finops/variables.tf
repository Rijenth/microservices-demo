variable "project_name" {
  type        = string
  description = "Project name used for resource naming and tagging"
}

variable "aws_region" {
  type        = string
  description = "AWS region (used in CloudWatch dashboard)"
}

variable "alert_email" {
  type        = string
  description = "Email address to receive budget and anomaly alerts (leave empty to disable)"
  default     = ""
}

variable "budget_currency" {
  type        = string
  description = "Currency for AWS Budgets (USD or EUR)"
  default     = "USD"
}

variable "monthly_budget_amount" {
  type        = number
  description = "Maximum total monthly spend — corresponds to total project budget (~2000€)"
  default     = 2200
}

variable "project_start_date" {
  type        = string
  description = "Date de début du projet au format RFC3339 (ex: 2026-04-07T00:00:00Z) — sert à calculer les bornes des 3 semaines"
}

variable "week1_budget_amount" {
  type        = number
  description = "Budget Semaine 1 — Setup & Fondations (CDC : ~200€)"
  default     = 220
}

variable "week2_budget_amount" {
  type        = number
  description = "Budget Semaine 2 — Hardening & Optimisation (CDC : ~500€)"
  default     = 550
}

variable "week3_budget_amount" {
  type        = number
  description = "Budget Semaine 3 — Pre-Black Friday (CDC : ~600€)"
  default     = 660
}

variable "daily_demo_budget_amount" {
  type        = number
  description = "Maximum daily spend during the Black Friday demo days (~200€ over 2 days)"
  default     = 120
}

variable "enable_anomaly_detection" {
  type        = bool
  description = "Active AWS Cost Anomaly Detection — nécessite ce:CreateAnomalyMonitor (désactiver si politique DenyBillingAccess)"
  default     = true
}

variable "anomaly_threshold_amount" {
  type        = number
  description = "Minimum absolute cost anomaly (in budget_currency) to trigger an alert"
  default     = 50
}

variable "ec2_instance_id" {
  type        = string
  description = "ID of the application EC2 instance (for CloudWatch alarms)"
}

variable "rds_instance_id" {
  type        = string
  description = "ID of the database EC2 instance (for CloudWatch alarms)"
}

variable "alb_arn_suffix" {
  type        = string
  description = "ARN suffix of the ALB (used for CloudWatch metrics, e.g. app/online-boutique-alb/abc123)"
}
