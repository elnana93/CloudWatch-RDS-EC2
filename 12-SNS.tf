
# ADD PagerDuty Later !!!!!!! (For experience)

resource "aws_sns_topic" "db_failure_alerts" {
  name = "db-connection-failure-alerts"
}

resource "aws_sns_topic_subscription" "sns_email" {
  topic_arn = aws_sns_topic.db_failure_alerts.arn
  protocol  = "email"
  endpoint  = "e5techmanagement@gmail.com"
}
