############################################
# CloudWatch Logs + Metric Filter + Alarm
############################################

# 1) Log group (CloudWatch Logs)
resource "aws_cloudwatch_log_group" "lab1b_app" {
  name              = "/lab1b/app"
  retention_in_days = 14
}

# 2) Metric Filter (Logs -> Metric)
resource "aws_cloudwatch_log_metric_filter" "lab1b_db_failures" {
  name           = "lab1b-db-failures"
  log_group_name = aws_cloudwatch_log_group.lab1b_app.name
  pattern        = "DB_CONNECTION_FAILURE"

  metric_transformation {
    name      = "DBConnectionFailures"
    namespace = "Lab1b/App"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_metric_alarm" "lab1b_db_failure_alarm" {
  alarm_name        = "lab1b-db-connection-failures"
  alarm_description = "Triggers when DB connection failures exceed threshold"

  namespace           = "Lab1b/App"
  metric_name         = "DBConnectionFailures"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 3
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.db_failure_alerts.arn]
  ok_actions    = [aws_sns_topic.db_failure_alerts.arn] # optional
}
