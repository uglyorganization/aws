# the ugly org vpc and networking 

# main vpc

resource "aws_vpc" "ugly_org" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "UglyOrg"
  }
}

resource "aws_subnet" "ugly_org_subnet" {
  vpc_id                  = aws_vpc.ugly_org.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "UglyOrg"
  }
}