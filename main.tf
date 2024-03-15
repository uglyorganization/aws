terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"

  backend "s3" {
    bucket = "terraform-state-46422794"
    key    = "terraform/terraform.tfstate"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = "eu-west-1"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "AWS_ACCOUNT_ID" {
  description = "AWS Account ID"
  type        = string
}

resource "random_id" "random" {
  byte_length = 8
}

# main vpc

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "main_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "main_a"
  }
}

resource "aws_subnet" "main_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "main-b"
  }
}

# github backend-lxd

resource "aws_iam_policy" "github_backend_lxd" {
  name        = "github-backend-lxd-ssm"
  description = "Policy granting access to SSM for backend-lxd deployment"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ssm:SendCommand",
        ],
        Resource = [
          "arn:aws:ssm:${var.region}:${var.AWS_ACCOUNT_ID}:document/AWS-RunShellScript",
          "arn:aws:ssm:${var.region}:${var.AWS_ACCOUNT_ID}:instance/*",
        ],
        Condition = {
          StringLike = {
            "ec2:ResourceTag/Application" : "backend-lxd"
          }
        }
      },
    ],
  })
}

resource "aws_iam_role" "github_backend_lxd" {
  name = "github-backend-lxd"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "arn:aws:iam::${var.AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" : "sts.amazonaws.com",
          },
          StringLike = {
            "token.actions.githubusercontent.com:sub" : "repo:uglyorganization/backend-lxd:*",
          },
        },
      },
    ],
  })
}

resource "aws_iam_policy_attachment" "github_backend_lxd" {
  name       = "github-backend-lxd-ssm-attach"
  roles      = [aws_iam_role.github_backend_lxd.name]
  policy_arn = aws_iam_policy.github_backend_lxd.arn
}

# ec2 asg elb setup for backend-lxd

resource "aws_launch_configuration" "backend_lxd" {
  name          = "backend-lxd-${random_id.random.hex}"
  ami           = "ami-0fc3317b37c1269d3"
  instance_type = "t2.micro"

  security_groups = ["${aws_security_group.backend_lxd.id}"]

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for the EC2 Instances/ASG
resource "aws_security_group" "backend_lxd" {
  name        = "backend-lxd"
  description = "Security group for backend-lxd instances"
  vpc_id      = aws_vpc.main.id # Specify your VPC ID

  # Allow inbound HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Standard outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_autoscaling_group" "backend_lxd" {
  launch_configuration = aws_launch_configuration.backend_lxd.name
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1

  vpc_zone_identifier = ["${aws_subnet.main.id}"] # List your subnet IDs

  tag {
    key                 = "Name"
    value               = "backend-lxd-instance"
    propagate_at_launch = true
  }
}

resource "aws_elb" "backend_lxd" {
  name               = "backend-lxd"
  availability_zones = ["${var.region}a", "${var.region}b"]

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/health"
    interval            = 30
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances                   = [aws_autoscaling_group.backend_lxd.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400
}

output "backend_lxd_elb_dns_name" {
  value = aws_elb.backend_lxd.dns_name
}
