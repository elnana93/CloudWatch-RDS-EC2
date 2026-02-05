#Here is the complete 1-VPC.tf file:
resource "aws_vpc" "vpc" {
  for_each   = var.vpcs
  cidr_block = each.value.cidr_block
  tags       = each.value.tags
}

output "vpc_ids" {
  description = "A map of VPC names to their IDs."
  value = {
    myvpc_id = aws_vpc.vpc["myvpc"].id
  }
}