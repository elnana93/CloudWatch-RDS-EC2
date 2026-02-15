
# Region variable for AWS provider

variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-west-2"
}

variable "vpcs" {
  description = "A map defining the name, CIDR block, and tags for each VPC."
  type = map(object({
    cidr_block = string
    tags       = map(string)
  }))
  default = {
    myvpc = {
      cidr_block = "10.50.0.0/16"
      tags       = { Name = "myvpc", Environment = "vpc4RDS" }
    }
  }
}

variable "public_subnet" {
  description = "Configuration for the public subnets in the VPC."
  type = map(object({
    cidr_block = string
    az         = string
    is_public  = bool
  }))
  default = {
    "public_a" = { cidr_block = "10.50.1.0/24", az = "us-west-2a", is_public = true }
    "public_b" = { cidr_block = "10.50.2.0/24", az = "us-west-2b", is_public = true }
    "public_c" = { cidr_block = "10.50.3.0/24", az = "us-west-2c", is_public = true }
  }
}

variable "private_subnet" {
  description = "Configuration for the private subnets in the VPC."
  type = map(object({
    cidr_block = string
    az         = string
    is_public  = bool
  }))
  default = {
    "private_a" = { cidr_block = "10.50.11.0/24", az = "us-west-2a", is_public = false }
    "private_b" = { cidr_block = "10.50.12.0/24", az = "us-west-2b", is_public = false }
    "private_c" = { cidr_block = "10.50.13.0/24", az = "us-west-2c", is_public = false }
  }
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed to SSH (port 22). Use your public IP /32."
  type        = list(string)
  default     = ["172.216.11.16/32"] # CHANGE to ["your.ip.address/32"] for safety
}





# Variables for EC2 {lab_ec2_app}

variable "instance_name" {
  type        = string
  description = "Value for the Name tag"
  default     = "lab_ec2_app"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

variable "key_name" {
  type        = string
  description = "Existing EC2 key pair name"
  default     = "key2026"
}

variable "ami_owners" {
  type        = list(string)
  description = "AMI owner IDs (Amazon = amazon)"
  default     = ["amazon"]
}

variable "ami_name_pattern" {
  type        = string
  description = "AMI name pattern filter"
  default     = "al2023-ami-*-x86_64"
}

variable "index_message" {
  type        = string
  description = "Message written to the Nginx index.html"
  default     = "Hello World I'm Here!!!!!"
}

variable "extra_tags" {
  type        = map(string)
  description = "Extra tags to apply to the instance"
  default     = {}
}









