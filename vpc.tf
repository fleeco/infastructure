resource "aws_vpc" "tlb-default" {
  cidr_block = "10.7.0.0/20"
  enable_dns_hostnames = true
  tags = {
    Name = "tlb-default-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.tlb-default.id

  tags = {
    Name = "InternetBreakout"
  }
}

resource "aws_egress_only_internet_gateway" "gw6" {
  vpc_id = aws_vpc.tlb-default.id

  tags = {
    Name = "ip6Gateway"
  }
}

resource "aws_route_table" "tlb-pub-route" {
  vpc_id = aws_vpc.tlb-default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.gw6.id
  }

  tags = {
    Name = "tlb-public-route-table"
  }
}

resource "aws_route_table" "tlb-priv-route" {
  vpc_id = aws_vpc.tlb-default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "tlb-private-route-table"
  }
}

resource "aws_subnet" "tlb-default-pub" { 
    vpc_id = aws_vpc.tlb-default.id
    cidr_block = "10.7.1.0/24"
    tags = {
        Name = "Public Subnet"
    }
}

resource "aws_subnet" "tlb-default-priv-a" { 
    vpc_id = aws_vpc.tlb-default.id
    cidr_block = "10.7.2.0/24"
    tags = {
        Name = "Private Subnet A"
    }
}

resource "aws_route_table_association" "pub" {
  subnet_id      = aws_subnet.tlb-default-pub.id
  route_table_id = aws_route_table.tlb-pub-route.id
}

resource "aws_route_table_association" "priv" {
  subnet_id      = aws_subnet.tlb-default-priv-a.id
  route_table_id = aws_route_table.tlb-priv-route.id
}