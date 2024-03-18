# the ugly org vpc and networking 

# main vpc

variable "availability_zones" {
  type    = list(string)
  default = ["a", "b", "c"]
}

resource "aws_vpc" "ugly_org" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "UglyOrgVPC"
  }
}

# Create public subnets
resource "aws_subnet" "ugly_org_public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.ugly_org.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = "${var.region}${var.availability_zones[count.index]}"
  map_public_ip_on_launch = true

  tags = {
    Name = "UglyOrgVPCPublic${var.availability_zones[count.index]}"
  }
}

# Create private subnets
resource "aws_subnet" "ugly_org_private" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.ugly_org.id
  cidr_block        = "10.0.${count.index + 4}.0/24"
  availability_zone = "${var.region}${var.availability_zones[count.index]}"

  tags = {
    Name = "UglyOrgVPCPrivate${var.availability_zones[count.index]}"
  }
}

# An Internet Gateway is necessary for allowing communication between resources in your VPC and the internet
# which is essential for a public-facing ELB.
resource "aws_internet_gateway" "ugly_org" {
  vpc_id = aws_vpc.ugly_org.id

  tags = {
    Name = "UglyOrgIGW"
  }
}

# VPC table that routes traffic destined for the internet (0.0.0.0/0) to the igw
resource "aws_route_table" "ugly_org_public_rt" {
  vpc_id = aws_vpc.ugly_org.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ugly_org.id
  }

  tags = {
    Name = "UglyOrgPublicRT"
  }
}

# associate the route table with your public subnets to ensure instances within those subnets can access the internet:
resource "aws_route_table_association" "ugly_org_public_rta" {
  count = length(aws_subnet.ugly_org_public[*].id)

  subnet_id      = aws_subnet.ugly_org_public[count.index].id
  route_table_id = aws_route_table.ugly_org_public_rt.id
}
