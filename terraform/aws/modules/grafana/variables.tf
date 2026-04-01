variable "project_name" {
  type        = string
  description = "Project name used for resource naming"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the Grafana EC2 instance (Amazon Linux 2)"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "subnet_id" {
  type        = string
  description = "Public subnet ID where Grafana will be deployed"
}

variable "security_group_id" {
  type        = string
  description = "Security group ID allowing port 3000"
}

variable "key_name" {
  type        = string
  description = "EC2 key pair name"
}

variable "aws_region" {
  type        = string
  description = "AWS region (passed to Grafana CloudWatch datasource)"
}

variable "admin_password" {
  type        = string
  description = "Grafana admin password"
  sensitive   = true
  default     = "admin"
}
