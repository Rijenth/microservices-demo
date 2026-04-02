variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
  default     = "eu-central-2"
}

variable "aws_access_key" {
  type        = string
  description = "AWS access key"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key"
  sensitive   = true
}

variable "project_name" {
  type        = string
  description = "Project name used for resource naming"
  default     = "online-boutique"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the EC2 instance"
  default     = "ami-095791d719c96cf1d"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "key_name" {
  type        = string
  description = "Name of the SSH key pair for EC2 access"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones to use"
  default = [
    "eu-west-3a",
    "eu-west-3b"
  ]
}

variable "db_username" {
  type        = string
  description = "Database master username"
  sensitive   = true
}

variable "db_password" {
  type        = string
  description = "Database master password"
  sensitive   = true
}

variable "eks_oidc_issuer_url" {
  type        = string
  description = "OIDC issuer URL from EKS cluster (empty to skip IRSA setup)"
  default     = ""
}

variable "grafana_admin_password" {
  type        = string
  description = "Grafana admin password"
  sensitive   = true
  default     = "admin"
}

# -------------------------------------------------------
# FinOps variables
# -------------------------------------------------------
variable "finops_alert_email" {
  type        = string
  description = "Email address to receive budget and cost anomaly alerts (leave empty to disable)"
  default     = ""
}

variable "budget_currency" {
  type        = string
  description = "Currency for AWS Budgets (USD recommended — AWS billing is in USD)"
  default     = "USD"
}

variable "monthly_budget_amount" {
  type        = number
  description = "Total monthly budget cap in budget_currency (~2000€ ≈ 2200 USD)"
  default     = 2200
}

variable "project_start_date" {
  type        = string
  description = "Date de début du projet au format RFC3339 (ex: 2026-04-07T00:00:00Z)"
  default     = "2026-04-07T00:00:00Z"
}

variable "week1_budget_amount" {
  type        = number
  description = "Budget Semaine 1 — Setup & Fondations (~200€ ≈ 220 USD)"
  default     = 220
}

variable "week2_budget_amount" {
  type        = number
  description = "Budget Semaine 2 — Hardening & Optimisation (~500€ ≈ 550 USD)"
  default     = 550
}

variable "week3_budget_amount" {
  type        = number
  description = "Budget Semaine 3 — Pre-Black Friday (~600€ ≈ 660 USD)"
  default     = 660
}

variable "daily_demo_budget_amount" {
  type        = number
  description = "Daily budget alert during Black Friday demo (~100€/jour ≈ 110 USD)"
  default     = 110
}

variable "enable_anomaly_detection" {
  type        = bool
  description = "Active AWS Cost Anomaly Detection (desactiver si politique DenyBillingAccess sur le compte)"
  default     = false
}

variable "anomaly_threshold_amount" {
  type        = number
  description = "Minimum cost anomaly to trigger an alert, in budget_currency"
  default     = 50
}

variable "use_spot_instance" {
  type        = bool
  description = "Use Spot Instances for EC2 to reduce costs by up to 70% (disable during Black Friday demo)"
  default     = false
}

variable "environment" {
  type        = string
  description = "Deployment environment (dev / staging / prod)"
  default     = "dev"
}
