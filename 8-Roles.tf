############################
# EC2 IAM ROLE + POLICIES + INSTANCE PROFILE
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

# Runtime: only what the app needs
resource "aws_iam_role_policy" "lab_ec2_permissions" {
  name = "lab-ec2-permissions"
  role = aws_iam_role.lab_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadDbSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.rds_mysql.arn
      }
    ]
  })
}


# Troubleshooting / instructor verification (optional)
resource "aws_iam_role_policy" "lab_ec2_troubleshooting" {
  name = "lab-ec2-troubleshooting"
  role = aws_iam_role.lab_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadSecretResourcePolicyOnly"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetResourcePolicy"]
        Resource = aws_secretsmanager_secret.rds_mysql.arn
      },
      {
        Sid    = "RdsDescribeOnly"
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBSubnetGroups"
        ]
        Resource = "*"
      },
      {
        Sid    = "Ec2DescribeOnly"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeVpcs"
        ]
        Resource = "*"
      },
      {
        Sid    = "LambdaReadRotationFunctionOnly"
        Effect = "Allow"
        Action = [
          "lambda:GetFunctionConfiguration",
          "lambda:GetFunction"
        ]
        Resource = "*"
      },
      {
        Sid    = "IamIntrospectRoleOnly"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:ListRolePolicies",
          "iam:GetRolePolicy",
          "iam:ListAttachedRolePolicies"
        ]
        Resource = aws_iam_role.lab_ec2_role.arn
      },
      {
        Sid      = "IamGetInstanceProfileOnly"
        Effect   = "Allow"
        Action   = ["iam:GetInstanceProfile"]
        Resource = aws_iam_instance_profile.lab_ec2_profile.arn
      },
      {
        Sid    = "IamReadAwsManagedPoliciesOnly"
        Effect = "Allow"
        Action = [
          "iam:GetPolicy",
          "iam:GetPolicyVersion"
        ]
        Resource = "arn:aws:iam::aws:policy/*"
      }
    ]

  })
}





resource "aws_iam_role_policy" "ec2_can_rotate_secret" {
  name = "lab-ec2-can-rotate-secret"
  role = aws_iam_role.lab_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:RotateSecret",
        "secretsmanager:UpdateSecretVersionStage",
        "secretsmanager:ListSecretVersionIds",
        "secretsmanager:CancelRotateSecret"
      ]
      Resource = aws_secretsmanager_secret.rds_mysql.arn
    }]
  })
}




resource "aws_iam_role_policy" "ec2_can_read_rotation_logs" {
  name = "lab-ec2-can-read-rotation-logs"
  role = aws_iam_role.lab_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:DescribeLogStreams",
        "logs:GetLogEvents",
        "logs:FilterLogEvents"
      ]
      Resource = [
        "arn:aws:logs:us-west-2:676373376093:log-group:/aws/lambda/lab-mysql-rotation:*"
      ]
    }]
  })
}






# IAM role for rotation lambda
resource "aws_iam_role" "mysql_rotation_lambda_role" {
  name = "lab-mysql-rotation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "mysql_rotation_lambda_policy" {
  name = "lab-mysql-rotation-lambda-policy"
  role = aws_iam_role.mysql_rotation_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # CloudWatch Logs
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },

      # If Lambda is in a VPC, it needs to manage ENIs
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ],
        Resource = "*"
      },

      # Secret-scoped rotation operations
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecretVersionStage"
        ],
        Resource = aws_secretsmanager_secret.rds_mysql.arn
      },

      # Must be Resource="*"
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetRandomPassword"],
        Resource = "*"
      }
    ]
  })
}


# This is very important: allow EC2 to invoke the rotation Lambda for troubleshooting
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
