#!/bin/bash
set -euo pipefail

# ── Install Grafana ────────────────────────────────────────────────────────────
cat > /etc/yum.repos.d/grafana.repo <<'EOF'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

yum install -y grafana

# ── Grafana main config ────────────────────────────────────────────────────────
cat > /etc/grafana/grafana.ini <<EOF
[server]
http_port = 3000

[security]
admin_user     = admin
admin_password = ${admin_password}

[auth.anonymous]
enabled  = true
org_role = Viewer

[paths]
provisioning = /etc/grafana/provisioning
EOF

# ── Provision: CloudWatch datasource ──────────────────────────────────────────
mkdir -p /etc/grafana/provisioning/datasources

cat > /etc/grafana/provisioning/datasources/cloudwatch.yaml <<EOF
apiVersion: 1
datasources:
  - name: CloudWatch
    type: cloudwatch
    uid: cloudwatch
    access: proxy
    isDefault: true
    jsonData:
      authType: ec2_iam_role
      defaultRegion: ${aws_region}
      logsTimeout: 60s
EOF

# ── Provision: CloudWatch Logs datasource ─────────────────────────────────────
cat > /etc/grafana/provisioning/datasources/cloudwatch-logs.yaml <<EOF
apiVersion: 1
datasources:
  - name: CloudWatch Logs
    type: cloudwatch
    uid: cloudwatch-logs
    access: proxy
    jsonData:
      authType: ec2_iam_role
      defaultRegion: ${aws_region}
      logsTimeout: 60s
EOF

# ── Provision: dashboards ─────────────────────────────────────────────────────
mkdir -p /etc/grafana/provisioning/dashboards
mkdir -p /var/lib/grafana/dashboards

cat > /etc/grafana/provisioning/dashboards/default.yaml <<EOF
apiVersion: 1
providers:
  - name: default
    orgId: 1
    folder: OnlineBoutique
    type: file
    updateIntervalSeconds: 30
    options:
      path: /var/lib/grafana/dashboards
EOF

# ── Dashboard: EC2 + ALB overview ─────────────────────────────────────────────
cat > /var/lib/grafana/dashboards/online-boutique-aws.json <<'DASHBOARD'
{
  "title": "Online Boutique – AWS",
  "uid": "online-boutique-aws",
  "schemaVersion": 38,
  "refresh": "30s",
  "time": {"from": "now-1h", "to": "now"},
  "panels": [
    {
      "id": 1,
      "title": "ALB – Request Count",
      "type": "timeseries",
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
      "datasource": {"uid": "cloudwatch"},
      "targets": [{
        "namespace": "AWS/ApplicationELB",
        "metricName": "RequestCount",
        "statistics": ["Sum"],
        "period": "60",
        "dimensions": {}
      }]
    },
    {
      "id": 2,
      "title": "ALB – HTTP 5xx Errors",
      "type": "timeseries",
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
      "datasource": {"uid": "cloudwatch"},
      "targets": [{
        "namespace": "AWS/ApplicationELB",
        "metricName": "HTTPCode_ELB_5XX_Count",
        "statistics": ["Sum"],
        "period": "60",
        "dimensions": {}
      }],
      "fieldConfig": {
        "defaults": {
          "color": {"mode": "fixed", "fixedColor": "red"}
        }
      }
    },
    {
      "id": 3,
      "title": "ALB – Target Response Time (p99)",
      "type": "timeseries",
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
      "datasource": {"uid": "cloudwatch"},
      "targets": [{
        "namespace": "AWS/ApplicationELB",
        "metricName": "TargetResponseTime",
        "statistics": ["p99"],
        "period": "60",
        "dimensions": {}
      }]
    },
    {
      "id": 4,
      "title": "EC2 – CPU Utilization (%)",
      "type": "timeseries",
      "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
      "datasource": {"uid": "cloudwatch"},
      "targets": [{
        "namespace": "AWS/EC2",
        "metricName": "CPUUtilization",
        "statistics": ["Average"],
        "period": "60",
        "dimensions": {}
      }]
    },
    {
      "id": 5,
      "title": "VPC Flow Logs",
      "type": "logs",
      "gridPos": {"h": 10, "w": 24, "x": 0, "y": 16},
      "datasource": {"uid": "cloudwatch"},
      "targets": [{
        "queryMode": "Logs",
        "logGroups": [{"name": "/aws/vpc/${project_name}-flow-logs"}],
        "expression": "fields @timestamp, @message | sort @timestamp desc | limit 100"
      }]
    }
  ]
}
DASHBOARD

# ── Provision: alert rules ─────────────────────────────────────────────────────
mkdir -p /etc/grafana/provisioning/alerting

cat > /etc/grafana/provisioning/alerting/aws-alerts.yaml <<EOF
apiVersion: 1
groups:
  - orgId: 1
    name: OnlineBoutique-AWS
    folder: OnlineBoutique
    interval: 1m
    rules:
      - uid: alb-high-errors
        title: "ALB High Error Rate"
        condition: B
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High 5xx error rate on ALB"
        data:
          - refId: A
            relativeTimeRange:
              from: 600
              to: 0
            datasourceUid: cloudwatch
            model:
              namespace: AWS/ApplicationELB
              metricName: HTTPCode_ELB_5XX_Count
              statistics: [Sum]
              period: "60"
              refId: A
          - refId: B
            relativeTimeRange:
              from: 600
              to: 0
            datasourceUid: "__expr__"
            model:
              conditions:
                - evaluator:
                    params: [10]
                    type: gt
                  operator:
                    type: and
                  query:
                    params: [A]
                  reducer:
                    params: []
                    type: sum
                  type: query
              datasource:
                type: __expr__
                uid: "__expr__"
              expression: A
              refId: B
              type: threshold

      - uid: ec2-high-cpu
        title: "EC2 High CPU"
        condition: B
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "EC2 CPU usage above 80%"
        data:
          - refId: A
            relativeTimeRange:
              from: 600
              to: 0
            datasourceUid: cloudwatch
            model:
              namespace: AWS/EC2
              metricName: CPUUtilization
              statistics: [Average]
              period: "60"
              refId: A
          - refId: B
            relativeTimeRange:
              from: 600
              to: 0
            datasourceUid: "__expr__"
            model:
              conditions:
                - evaluator:
                    params: [80]
                    type: gt
                  operator:
                    type: and
                  query:
                    params: [A]
                  reducer:
                    params: []
                    type: last
                  type: query
              datasource:
                type: __expr__
                uid: "__expr__"
              expression: A
              refId: B
              type: threshold
EOF

# ── Start Grafana ──────────────────────────────────────────────────────────────
systemctl daemon-reload
systemctl enable grafana-server
systemctl start grafana-server
