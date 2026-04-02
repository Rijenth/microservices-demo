# IAM role so Grafana can read CloudWatch without static credentials
resource "aws_iam_role" "grafana" {
  name = "${var.project_name}-grafana"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.project_name}-grafana" }
}

resource "aws_iam_role_policy" "grafana_cloudwatch" {
  name = "${var.project_name}-grafana-cloudwatch"
  role = aws_iam_role.grafana.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics",
          "cloudwatch:DescribeAlarms",
          "logs:DescribeLogGroups",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartQuery",
          "logs:StopQuery",
          "logs:GetQueryResults",
          "ec2:DescribeInstances",
          "ec2:DescribeRegions",
          "tag:GetResources"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "grafana" {
  name = "${var.project_name}-grafana"
  role = aws_iam_role.grafana.name
}

# Grafana EC2 instance
resource "aws_instance" "grafana" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.grafana.name

  user_data = templatefile("${path.module}/scripts/setup-grafana.sh", {
    aws_region     = var.aws_region
    admin_password = var.admin_password
    project_name   = var.project_name
  })

  tags = { Name = "${var.project_name}-grafana" }
}
