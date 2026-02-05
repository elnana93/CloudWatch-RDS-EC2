
############################################
# Lambda for Secrets Manager MySQL Rotation
############################################

locals {
  rotation_zip = "${path.module}/dist/rotation.zip"
}

# Log group (optional but nice)
resource "aws_cloudwatch_log_group" "mysql_rotation" {
  name              = "/aws/lambda/lab-mysql-rotation"
  retention_in_days = 14
}



data "aws_region" "current" {}
data "aws_partition" "current" {}


# The Lambda function (uploads your already-built dist/rotation.zip)
resource "aws_lambda_function" "mysql_rotation" {
  function_name = "lab-mysql-rotation"

  role    = aws_iam_role.mysql_rotation_lambda_role.arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.11"

  filename         = "${path.module}/dist/rotation.zip"
  source_code_hash = filebase64sha256("${path.module}/dist/rotation.zip")



  timeout     = 120
  memory_size = 256

  environment {
    variables = {
      SECRETS_MANAGER_ENDPOINT = "https://secretsmanager.${data.aws_region.current.name}.${data.aws_partition.current.dns_suffix}"

      # optional, but helpful (and avoids the password chars that broke RDS earlier)
      EXCLUDE_CHARACTERS = "/@\\\" "
      PASSWORD_LENGTH    = "24"
    }
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.private_subnet["private_a"].id,
      aws_subnet.private_subnet["private_b"].id
    ]
    security_group_ids = [aws_security_group.rotation_lambda_sg.id]
  }

  depends_on = [aws_cloudwatch_log_group.mysql_rotation]
}

# Allow Secrets Manager to invoke the Lambda for THIS secret
resource "aws_lambda_permission" "allow_secretsmanager_invoke" {
  statement_id  = "AllowSecretsManagerInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mysql_rotation.function_name
  principal     = "secretsmanager.amazonaws.com"
  source_arn    = aws_secretsmanager_secret.rds_mysql.arn
}


