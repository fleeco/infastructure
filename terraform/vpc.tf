## var.number_of_az is kind of hacky, but this lets me launch the cluster in any region I want and 
## dynamically grab the AZ's in alphabetical order.  Also, the CIDR notation is def kind of shit but 
## 256 IP's is more than enough for any of the garbage I'm going to be dealing with anyway.

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

## Creates var.number_of_az public subnets
resource "aws_subnet" "public" {
  count                   = length(range(0,var.number_of_az))
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${(2 * count.index)}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "Public Subnet ${data.aws_availability_zones.available.names[count.index]}"
    "kubernetes.io/role/elb" = "1"
  }
}

## Creates var.number_of_az private subnets
resource "aws_subnet" "private" {
  count                   = length(range(0,var.number_of_az))
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${(2 * count.index) + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "Private Subnet ${data.aws_availability_zones.available.names[count.index]}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

## One gateway to rule them all
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

## Create one EIP for each NAT gateway
resource "aws_eip" "private_nat" {
  count = length(aws_subnet.private)
  vpc   = true
}

## Create 1 NAT gateway in each of the public subnets
resource "aws_nat_gateway" "private" {
  count           = length(aws_subnet.private)
  allocation_id   = aws_eip.private_nat[count.index].id
  subnet_id       = aws_subnet.public[count.index].id
}


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "private" {
  count = length(aws_subnet.private)
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route" "private_nat_gateway" {
  count                  = length(aws_subnet.private)
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.private[count.index].id
}

resource "aws_route_table_association" "public" {
  count           = length(aws_subnet.public)
  subnet_id       = aws_subnet.public[count.index].id
  route_table_id  = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count           = length(aws_subnet.private)
  subnet_id       = aws_subnet.private[count.index].id
  route_table_id  = aws_route_table.private[count.index].id
}