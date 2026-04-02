variable "project_name" {
  type        = string
  description = "Project name used for resource naming"
}

variable "ami_id" {
  type        = string
  description = "AMI ID for the EC2 instance"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where the EC2 instance will be launched"
}

variable "security_group_id" {
  type        = string
  description = "Security group ID for the EC2 instance"
}

variable "key_name" {
  type        = string
  description = "Name of the SSH key pair"
}

variable "use_spot" {
  type        = bool
  description = "Enable Spot Instance pricing for cost savings (up to 70% cheaper, but interruptible)"
  default     = false
}

variable "environment" {
  type        = string
  description = "Deployment environment tag (dev / staging / prod)"
  default     = "dev"
}
