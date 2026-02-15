
/* 
“SSM Parameter Store provides a centralized, non-hardcoded source for DB connection 
settings (host/port/dbname), enabling reliable application connectivity 
and faster recovery during incidents, which improves user experience indirectly.”
 */
 
resource "aws_ssm_parameter" "db_host" {
  name  = "/lab1b/db/host"
  type  = "String"
  value = aws_db_instance.lab_mysql.address
}

resource "aws_ssm_parameter" "db_port" {
  name  = "/lab1b/db/port"
  type  = "String"
  value = tostring(aws_db_instance.lab_mysql.port)
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/lab1b/db/name"
  type  = "String"
  value = "notes"
}



