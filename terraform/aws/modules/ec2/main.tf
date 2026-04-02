resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  user_data              = file("${path.module}/script/userdata.sh")

  # Spot Instance — économie jusqu'à 70% sur les instances on-demand
  # Utiliser uniquement hors démo Black Friday (risque d'interruption)
  dynamic "instance_market_options" {
    for_each = var.use_spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        # "stop" préserve l'état en cas d'interruption (vs "terminate")
        instance_interruption_behavior = "stop"
        spot_instance_type             = "persistent"
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-ec2"
    Project     = var.project_name
    Environment = var.environment
    CostCenter  = "black-friday-survival"
    Tier        = "application"
    SpotEnabled = tostring(var.use_spot)
  }
}
