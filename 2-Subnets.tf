resource "aws_subnet" "public_subnet" {
  for_each = var.public_subnet

  vpc_id            = aws_vpc.vpc["myvpc"].id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.az

  map_public_ip_on_launch = each.value.is_public

  tags = {
    Name    = "public_subnet-${each.key}"
    Network = "Public"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc["myvpc"].id

}
#Route tables and IGW would be defined here for public subnets
#Do it ASAP Finish this!!!!

resource "aws_subnet" "private_subnet" {
  for_each = var.private_subnet

  vpc_id            = aws_vpc.vpc["myvpc"].id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.az

  map_public_ip_on_launch = each.value.is_public

  tags = {
    Name    = "private_subnet-${each.key}"
    Network = "Private"
  }
}

resource "aws_eip" "eip_nat" {
  domain = "vpc"
  tags = {
    Name = "eip_nat"
  }
}

#You need a public sebnet for a NAT in order to talk to the internet
#A private subnet won't work because it doesnt have route to the Internet Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip_nat.id
  subnet_id     = aws_subnet.public_subnet["public_b"].id

  tags = {
    Name = "nat"
  }
}
