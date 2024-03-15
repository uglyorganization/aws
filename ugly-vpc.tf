# the ugly org vpc and networking 

# main vpc

resource "aws_vpc" "ugly_org" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "UglyOrg"
  }
}
