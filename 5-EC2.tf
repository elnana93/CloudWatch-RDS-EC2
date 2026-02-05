

data "aws_ami" "al2023" {
  most_recent = true
  owners      = var.ami_owners

  filter {
    name   = "name"
    values = [var.ami_name_pattern]
  }
}

locals {
  startup_b64 = base64encode(file("${path.module}/startup.sh"))
}

resource "aws_instance" "lab_ec2_app" {
  ami                  = data.aws_ami.al2023.id
  instance_type        = var.instance_type
  key_name             = var.key_name
  iam_instance_profile = aws_iam_instance_profile.lab_ec2_profile.name


  vpc_security_group_ids = [aws_security_group.sg_ec2_lab.id]
  subnet_id              = aws_subnet.public_subnet["public_a"].id

  user_data_replace_on_change = true

  tags = merge(
    { Name = var.instance_name },
    var.extra_tags
  )

  # inside your aws_instance resource:
  user_data = <<-EOF
#!/bin/bash
set -euxo pipefail

printf '%s' '${local.startup_b64}' | base64 -d > /usr/local/bin/startup.sh
chmod +x /usr/local/bin/startup.sh

/usr/local/bin/startup.sh > /var/log/startup.log 2>&1
EOF


}



output "lab_ec2_instance_profile_name" {
  value = aws_iam_instance_profile.lab_ec2_profile.name
}

output "lab_ec2_public_ip" {
  value = aws_instance.lab_ec2_app.public_ip
}

output "lab_ec2_public_dns" {
  value = aws_instance.lab_ec2_app.public_dns
}

output "lab_ec2_public_url" {
  value = "http://${coalesce(aws_instance.lab_ec2_app.public_dns, aws_instance.lab_ec2_app.public_ip)}"
}

output "lab_ec2_ssh_command" {
  description = "SSH command to connect to the EC2 instance (Amazon Linux 2023)."
  value       = "ssh -i ${path.module}/${var.key_name}.pem ec2-user@${coalesce(aws_instance.lab_ec2_app.public_dns, aws_instance.lab_ec2_app.public_ip)}"
}
