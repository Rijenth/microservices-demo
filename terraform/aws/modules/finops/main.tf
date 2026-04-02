data "aws_caller_identity" "current" {}

# -------------------------------------------------------
# SNS — canal d'alertes centralisé
# -------------------------------------------------------

resource "aws_sns_topic" "cost_alerts" {
  name = "${var.project_name}-cost-alerts"

  tags = {
    Name       = "${var.project_name}-cost-alerts"
    Project    = var.project_name
    CostCenter = var.project_name
    Module     = "finops"
  }
}

resource "aws_sns_topic_policy" "cost_alerts" {
  arn    = aws_sns_topic.cost_alerts.arn
  policy = data.aws_iam_policy_document.sns_policy.json
}

data "aws_iam_policy_document" "sns_policy" {
  # AWS Budgets publie les alertes de dépassement
  statement {
    sid    = "AllowBudgets"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["budgets.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.cost_alerts.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  # Cost Anomaly Detection publie les anomalies de coûts
  # Pas de condition SourceAccount : ce service ne l'envoie pas
  statement {
    sid    = "AllowCostAnomalyDetection"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["costalerts.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.cost_alerts.arn]
  }
}

# Abonnement email optionnel (confirmation manuelle requise après terraform apply)
resource "aws_sns_topic_subscription" "email" {
  count     = var.alert_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.cost_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# -------------------------------------------------------
# AWS Budgets — 3 niveaux de granularité
# -------------------------------------------------------

# Budget mensuel — plafond global (1500-2000€ sur toute la durée du projet)
resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_amount)
  limit_unit   = var.budget_currency
  time_unit    = "MONTHLY"

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 50
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  # Alerte prévisionnelle : AWS prédit un dépassement avant qu'il arrive
  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 90
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  tags = {
    Project    = var.project_name
    CostCenter = var.project_name
    Module     = "finops"
  }
}

# Budget journalier — granularité fine pendant les 2 jours de démo Black Friday
resource "aws_budgets_budget" "daily_demo" {
  name         = "${var.project_name}-daily-demo"
  budget_type  = "COST"
  limit_amount = tostring(var.daily_demo_budget_amount)
  limit_unit   = var.budget_currency
  time_unit    = "DAILY"

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 75
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  tags = {
    Project    = var.project_name
    CostCenter = var.project_name
    Module     = "finops"
  }
}

# -------------------------------------------------------
# AWS Cost Anomaly Detection
# -------------------------------------------------------

# Surveille les écarts de coûts par service AWS (EC2, WAF, ELB, etc.)
# Nécessite la permission ce:CreateAnomalyMonitor — désactiver si refus IAM (enable_anomaly_detection = false)
resource "aws_ce_anomaly_monitor" "project" {
  count             = var.enable_anomaly_detection ? 1 : 0
  name              = "${var.project_name}-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"

  tags = {
    Project    = var.project_name
    CostCenter = var.project_name
    Module     = "finops"
  }
}

resource "aws_ce_anomaly_subscription" "project" {
  count     = var.enable_anomaly_detection ? 1 : 0
  name      = "${var.project_name}-anomaly-subscription"
  frequency = "IMMEDIATE"

  monitor_arn_list = [aws_ce_anomaly_monitor.project[0].arn]

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.cost_alerts.arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      values        = [tostring(var.anomaly_threshold_amount)]
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }

  tags = {
    Project    = var.project_name
    CostCenter = var.project_name
    Module     = "finops"
  }
}

# -------------------------------------------------------
# Resource Group — Attribution des coûts par projet
# -------------------------------------------------------
# Permet de filtrer toutes les ressources du projet dans AWS Cost Explorer
# via le tag CostCenter. Sans ça, les coûts sont noyés dans le compte global.

resource "aws_resourcegroups_group" "project" {
  name        = "${var.project_name}-resources"
  description = "Ressources du projet ${var.project_name} - suivi FinOps"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [{
        Key    = "CostCenter"
        Values = [var.project_name]
      }]
    })
  }

  tags = {
    Project    = var.project_name
    CostCenter = var.project_name
    Module     = "finops"
  }
}

# -------------------------------------------------------
# CloudWatch Alarms — rightsizing & performance
# -------------------------------------------------------

# CPU trop élevé → instance sous-dimensionnée, risque de crash pendant la démo
resource "aws_cloudwatch_metric_alarm" "app_high_cpu" {
  alarm_name          = "${var.project_name}-app-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "CPU > 85% pendant 15min — envisager un scale-up ou optimisation du code"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]
  ok_actions          = [aws_sns_topic.cost_alerts.arn]

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  tags = {
    Project    = var.project_name
    CostCenter = var.project_name
    Module     = "finops"
  }
}

# CPU trop bas → instance sur-dimensionnée, argent gaspillé (rightsizing)
resource "aws_cloudwatch_metric_alarm" "app_low_cpu" {
  alarm_name          = "${var.project_name}-app-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 6
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 3600
  statistic           = "Average"
  threshold           = 5
  alarm_description   = "CPU < 5% pendant 6h — instance sur-dimensionnée, downgrade possible"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]

  dimensions = {
    InstanceId = var.ec2_instance_id
  }

  tags = {
    Project    = var.project_name
    CostCenter = var.project_name
    Module     = "finops"
  }
}

resource "aws_cloudwatch_metric_alarm" "db_high_cpu" {
  alarm_name          = "${var.project_name}-db-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "CPU DB > 85% pendant 15min — goulot d'étranglement base de données"
  alarm_actions       = [aws_sns_topic.cost_alerts.arn]
  ok_actions          = [aws_sns_topic.cost_alerts.arn]

  dimensions = {
    InstanceId = var.rds_instance_id
  }

  tags = {
    Project    = var.project_name
    CostCenter = var.project_name
    Module     = "finops"
  }
}

# -------------------------------------------------------
# CloudWatch Dashboard — reporting FinOps opérationnel
# -------------------------------------------------------

resource "aws_cloudwatch_dashboard" "finops" {
  dashboard_name = "${var.project_name}-finops"

  dashboard_body = jsonencode({
    widgets = [
      # Bandeau de contexte budgétaire
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 3
        properties = {
          markdown = "## Black Friday Survival — FinOps\n| Phase | Budget | Seuil alerte |\n|---|---|---|\n| Semaine 1 — Setup | ~200 USD | Hebdo 80% |\n| Semaine 2 — Hardening | ~500 USD | Hebdo 80% |\n| Semaine 3 — Pre-Black Friday | ~600 USD | Hebdo 80% |\n| Demo Black Friday (2j) | ~200 USD | Journalier 75% |\n| **TOTAL** | **~${var.monthly_budget_amount} ${var.budget_currency}** | Mensuel 80% / 100% |\n\n📊 Analyse détaillée → [AWS Cost Explorer](https://console.aws.amazon.com/cost-management/home)"
        }
      },

      # CPU — rightsizing des deux instances
      {
        type   = "metric"
        x      = 0
        y      = 3
        width  = 12
        height = 6
        properties = {
          title  = "EC2 CPU — Rightsizing (cible : 40-70%)"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.ec2_instance_id,
              { stat = "Average", period = 300, label = "App EC2" }
            ],
            ["AWS/EC2", "CPUUtilization", "InstanceId", var.rds_instance_id,
              { stat = "Average", period = 300, label = "DB EC2" }
            ]
          ]
          yAxis = { left = { min = 0, max = 100 } }
          annotations = {
            horizontal = [
              { label = "Rightsizing min (5%)", value = 5, color = "#1f77b4" },
              { label = "Zone cible (40%)", value = 40, color = "#2ca02c" },
              { label = "Alerte scale-up (85%)", value = 85, color = "#d62728" }
            ]
          }
        }
      },

      # Trafic réseau — sortant facturé par AWS
      {
        type   = "metric"
        x      = 12
        y      = 3
        width  = 12
        height = 6
        properties = {
          title  = "EC2 Network Out — Trafic sortant (facturable)"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/EC2", "NetworkOut", "InstanceId", var.ec2_instance_id,
              { stat = "Sum", period = 3600, label = "App — bytes/h" }
            ],
            ["AWS/EC2", "NetworkIn", "InstanceId", var.ec2_instance_id,
              { stat = "Sum", period = 3600, label = "App — bytes/h entrant" }
            ]
          ]
        }
      },

      # Requêtes ALB — corrélation trafic/coût WAF
      {
        type   = "metric"
        x      = 0
        y      = 9
        width  = 8
        height = 6
        properties = {
          title  = "ALB — Volume de requêtes"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix,
              { stat = "Sum", period = 300, label = "Requêtes/5min" }
            ]
          ]
        }
      },

      # Erreurs 5xx ALB — signe de problème applicatif sous charge
      {
        type   = "metric"
        x      = 8
        y      = 9
        width  = 8
        height = 6
        properties = {
          title  = "ALB — Erreurs 5xx (dégradation sous charge)"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix,
              { stat = "Sum", period = 300, label = "5xx/5min", color = "#d62728" }
            ],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix,
              { stat = "Sum", period = 300, label = "Target 5xx/5min", color = "#ff7f0e" }
            ]
          ]
        }
      },

      # WAF — requêtes bloquées (coût WAF corrélé au trafic)
      {
        type   = "metric"
        x      = 16
        y      = 9
        width  = 8
        height = 6
        properties = {
          title  = "WAF — Requêtes bloquées"
          region = var.aws_region
          view   = "timeSeries"
          metrics = [
            ["AWS/WAFV2", "BlockedRequests",
              "WebACL", "${var.project_name}-waf",
              "Rule", "ALL",
              "Region", var.aws_region,
              { stat = "Sum", period = 300, label = "Bloquées/5min", color = "#e377c2" }
            ]
          ]
        }
      },

      # État des alarmes FinOps en temps réel
      {
        type   = "alarm"
        x      = 0
        y      = 15
        width  = 24
        height = 3
        properties = {
          title  = "État des alarmes FinOps"
          region = var.aws_region
          alarms = [
            aws_cloudwatch_metric_alarm.app_high_cpu.arn,
            aws_cloudwatch_metric_alarm.app_low_cpu.arn,
            aws_cloudwatch_metric_alarm.db_high_cpu.arn,
          ]
        }
      }
    ]
  })
}

# -------------------------------------------------------
# Budgets par semaine — période fixe par phase du projet
# AWS Budgets ne supporte pas WEEKLY, mais supporte des
# périodes fixes (time_period_start / time_period_end).
# On crée un budget par semaine calé sur les phases du CDC.
# -------------------------------------------------------

locals {
  # Calcul des bornes de chaque semaine à partir de la date de début du projet
  week1_start = formatdate("YYYY-MM-DD_00:00", var.project_start_date)
  week1_end   = formatdate("YYYY-MM-DD_00:00", timeadd(var.project_start_date, "168h"))
  week2_start = formatdate("YYYY-MM-DD_00:00", timeadd(var.project_start_date, "168h"))
  week2_end   = formatdate("YYYY-MM-DD_00:00", timeadd(var.project_start_date, "336h"))
  week3_start = formatdate("YYYY-MM-DD_00:00", timeadd(var.project_start_date, "336h"))
  week3_end   = formatdate("YYYY-MM-DD_00:00", timeadd(var.project_start_date, "504h"))
}

# Semaine 1 — Setup & Fondations (~200 USD)
resource "aws_budgets_budget" "week1" {
  name              = "${var.project_name}-semaine1-setup"
  budget_type       = "COST"
  limit_amount      = tostring(var.week1_budget_amount)
  limit_unit        = var.budget_currency
  time_unit         = "MONTHLY"
  time_period_start = local.week1_start
  time_period_end   = local.week1_end

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  tags = {
    Project    = var.project_name
    CostCenter = var.project_name
    Module     = "finops"
  }
}

# Semaine 2 — Hardening & Optimisation (~500 USD)
resource "aws_budgets_budget" "week2" {
  name              = "${var.project_name}-semaine2-hardening"
  budget_type       = "COST"
  limit_amount      = tostring(var.week2_budget_amount)
  limit_unit        = var.budget_currency
  time_unit         = "MONTHLY"
  time_period_start = local.week2_start
  time_period_end   = local.week2_end

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  tags = {
    Project    = var.project_name
    CostCenter = var.project_name
    Module     = "finops"
  }
}

# Semaine 3 — Pre-Black Friday (~600 USD)
resource "aws_budgets_budget" "week3" {
  name              = "${var.project_name}-semaine3-preblackfriday"
  budget_type       = "COST"
  limit_amount      = tostring(var.week3_budget_amount)
  limit_unit        = var.budget_currency
  time_unit         = "MONTHLY"
  time_period_start = local.week3_start
  time_period_end   = local.week3_end

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.cost_alerts.arn]
  }

  tags = {
    Project    = var.project_name
    CostCenter = var.project_name
    Module     = "finops"
  }
}
