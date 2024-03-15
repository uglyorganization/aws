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
  cidr_block        = "10.0.${count.index + 101}.0/24"
  availability_zone = "${var.region}${var.availability_zones[count.index]}"

  tags = {
    Name = "UglyOrgVPCPrivate${var.availability_zones[count.index]}"
  }
}

