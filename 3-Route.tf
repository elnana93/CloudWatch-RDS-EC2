
#Route Tables for Public and Private Subnets

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc["myvpc"].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private_route_table"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc["myvpc"].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_route_table"
  }
}


resource "aws_route_table_association" "private-us-west-2a" {
  subnet_id      = aws_subnet.private_subnet["private_a"].id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private-us-west-2b" {
  subnet_id      = aws_subnet.private_subnet["private_b"].id
  route_table_id = aws_route_table.private_route_table.id
}
resource "aws_route_table_association" "private-us-west-2c" {
  subnet_id      = aws_subnet.private_subnet["private_c"].id
  route_table_id = aws_route_table.private_route_table.id
}


#public

resource "aws_route_table_association" "public-us-west-2a" {
  subnet_id      = aws_subnet.public_subnet["public_a"].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public-us-west-2b" {
  subnet_id      = aws_subnet.public_subnet["public_b"].id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public-us-west-2c" {
  subnet_id      = aws_subnet.public_subnet["public_c"].id
  route_table_id = aws_route_table.public_route_table.id
} 