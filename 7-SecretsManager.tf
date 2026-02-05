

# Create the secret container
resource "aws_secretsmanager_secret" "rds_mysql" {
  name                    = "lab/rds/mysql"
  recovery_window_in_days = 0 # No recovery window for lab purposes


  tags = {
    Name = "lab-rds-mysql"
  }

}

# Put the secret value (JSON) into Secrets Manager
resource "aws_secretsmanager_secret_version" "rds_mysql" {
  secret_id = aws_secretsmanager_secret.rds_mysql.id

  secret_string = jsonencode({
    username = "admin"
    password = random_password.db.result
    engine   = "mysql"
    host     = aws_db_instance.lab_mysql.address
    port     = aws_db_instance.lab_mysql.port
    dbname   = aws_db_instance.lab_mysql.db_name
  })

  lifecycle {
    # CRITICAL: Prevents Terraform from overwriting the password 
    # if it is rotated by AWS Secrets Manager Rotation or manually in the console.
    ignore_changes = [secret_string]
  }
}





# Attach rotation schedule to the secret
resource "aws_secretsmanager_secret_rotation" "mysql_rotation" {
  secret_id           = aws_secretsmanager_secret.rds_mysql.id
  rotation_lambda_arn = aws_lambda_function.mysql_rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }
}











/* 
output "rds_mysql_rotation_stack_outputs" {
  value = aws_cloudformation_stack.rds_mysql_rotation.outputs
} */


/* output "rotation_lambda_name" {
  value = aws_cloudformation_stack.rds_mysql_rotation.outputs["RotationLambdaName"]
}

output "rotation_lambda_arn" {
  value = aws_cloudformation_stack.rds_mysql_rotation.outputs["RotationLambdaArn"]
}
 */