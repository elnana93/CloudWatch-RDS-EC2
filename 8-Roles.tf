############################
# EC2 IAM ROLE + PROFILE
############################

resource "aws_iam_role" "lab_ec2_role" {
  name = "lab-ec2-secrets-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "lab_ec2_profile" {
  name = "lab-ec2-secrets-profile"
  role = aws_iam_role.lab_ec2_role.name
}

############################
# EC2 Runtime Permissions (minimal + useful)
############################

resource "aws_iam_role_policy" "lab_ec2_runtime" {
  name = "lab-ec2-runtime"
  role = aws_iam_role.lab_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 1) Read DB secret (app uses this to connect)
      {
        Sid    = "ReadDbSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.rds_mysql.arn
      },

      # 2) Read DB params from SSM Parameter Store
      {
        Sid    = "ReadDbParamsFromSsm"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        "Resource" : "arn:aws:ssm:us-west-2:676373376093:parameter/lab1b/db/*"
      }
      ,
      {
        "Sid" : "AllowDescribeSSMParameters",
        "Effect" : "Allow",
        "Action" : "ssm:DescribeParameters",
        "Resource" : "*"
      },

      # 3) OPTIONAL: allow EC2 to read app logs in CloudWatch (so filter-log-events works from EC2)
      {
        Sid    = "ReadLab1bAppLogs"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "arn:aws:logs:us-west-2:676373376093:log-group:/lab1b/app:*"
      },

      # 4) OPTIONAL: allow EC2 to read the rotation Lambda logs (nice for troubleshooting)
      {
        Sid    = "ReadRotationLambdaLogs"
        Effect = "Allow"
        Action = [
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "arn:aws:logs:us-west-2:676373376093:log-group:/aws/lambda/lab-mysql-rotation:*"
      },
      {
        "Sid" : "AllowDescribeRdsUsWest2Only",
        "Effect" : "Allow",
        "Action" : "rds:DescribeDBInstances",
        "Resource" : "*",
        "Condition" : {
          "StringEquals" : {
            "aws:RequestedRegion" : "us-west-2"
          }
        }
      }

    ]
  })
}

############################
# CloudWatch Agent on EC2 (writes logs/metrics)
############################

resource "aws_iam_role_policy_attachment" "ec2_cloudwatch_agent" {
  role       = aws_iam_role.lab_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}


resource "aws_iam_role_policy" "ec2_can_invoke_rotation_lambda" {
  name = "lab-ec2-can-invoke-rotation-lambda"
  role = aws_iam_role.lab_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["lambda:InvokeFunction"],
      Resource = "arn:aws:lambda:us-west-2:676373376093:function:lab-mysql-rotation"
    }]
  })
}



#############################################################
# Rotation Lambda IAM Role (best practice: managed + scoped)
#############################################################

resource "aws_iam_role" "mysql_rotation_lambda_role" {
  name = "lab-mysql-rotation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Basic logging for Lambda → CloudWatch Logs
resource "aws_iam_role_policy_attachment" "rotation_lambda_basic_logs" {
  role       = aws_iam_role.mysql_rotation_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# If your rotation Lambda runs in a VPC (yours does, since you made a SG), it needs ENI permissions
resource "aws_iam_role_policy_attachment" "rotation_lambda_vpc_access" {
  role       = aws_iam_role.mysql_rotation_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Secret-scoped rotation permissions
resource "aws_iam_role_policy" "mysql_rotation_lambda_secret_policy" {
  name = "lab-mysql-rotation-lambda-secret-policy"
  role = aws_iam_role.mysql_rotation_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "RotateThisSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ]
        Resource = aws_secretsmanager_secret.rds_mysql.arn
      },
      {
        Sid      = "GetRandomPassword"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetRandomPassword"]
        Resource = "*"
      }
    ]
  })
}



resource "aws_iam_role_policy" "ec2_can_read_app_logs" {
  name = "lab-ec2-can-read-app-logs"
  role = aws_iam_role.lab_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ReadLab1bAppLogs"
      Effect = "Allow"
      Action = [
        "logs:DescribeLogStreams",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ]
      Resource = [
        "arn:aws:logs:us-west-2:676373376093:log-group:/lab1b/app:*"
      ]
    }]
  })
}







resource "aws_iam_role_policy" "ec2_cloudwatch_read_metric" {
  name = "lab-ec2-cloudwatch-read-metric"
  role = aws_iam_role.lab_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = "ReadOnlyDbFailureMetric"
      Effect = "Allow"
      Action = [
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics"
      ]
      Resource = "*"
    }]
  })
}


resource "aws_iam_role_policy" "ec2_cloudwatch_read_alarms" {
  name = "lab-ec2-cloudwatch-read-alarms"
  role = aws_iam_role.lab_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid    = "CloudWatchDescribeAlarms"
      Effect = "Allow",
      Action = [
        "cloudwatch:DescribeAlarms",
        "cloudwatch:DescribeAlarmsForMetric"
      ],
      Resource = "*"
    }]
  })
}



