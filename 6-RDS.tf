

# Generate a strong password
resource "random_password" "db" {
  length  = 24
  special = true
  /* # Ensures the password isn't regenerated unless explicitly changed
  lifecycle {
    ignore_changes = [length, special]
  } */
  # RDS disallows: / @ " (double quote) and spaces
  override_special = "!#$%&'()*+,-.:;<=>?[]^_`{|}~"
}



resource "aws_db_subnet_group" "lab_mysql_subnet_group" {
  name = "lab-mysql-subnet-group"
  subnet_ids = [
    aws_subnet.private_subnet["private_a"].id,
    aws_subnet.private_subnet["private_b"].id,
    # aws_subnet.private_subnet["private_c"].id, # optional
  ]

  tags = { Name = "lab-mysql-subnet-group" }
}

resource "aws_db_instance" "lab_mysql" {
  identifier = "lab-mysql"

  engine            = "mysql"
  instance_class    = "db.t3.micro" # free-tier-ish
  allocated_storage = 20
  storage_type      = "gp3"

  username = "admin"

  password = random_password.db.result

  db_subnet_group_name   = aws_db_subnet_group.lab_mysql_subnet_group.name
  vpc_security_group_ids = [aws_security_group.sg_rds_lab.id]
  publicly_accessible    = false

  multi_az            = false
  deletion_protection = false
  skip_final_snapshot = true


  lifecycle {
    ignore_changes = [password]
  }

  tags = { Name = "lab-mysql" }
}

output "rds_endpoint" {
  value = aws_db_instance.lab_mysql.address
}

output "app_db_secret_arn" {
  value = aws_secretsmanager_secret.rds_mysql.arn
}



