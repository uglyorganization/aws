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
            "ec2:ResourceTag/Application" : "BackendLXD"
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

# ec2

resource "aws_security_group" "backend_lxd" {
  name        = "backend-lxd"
  description = "Security group for backend-lxd instances"
  vpc_id      = aws_vpc.ugly_org.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "backend_lxd" {
  name_prefix     = "backend-lxd-"
  image_id        = "ami-0c02fb55956c7d316"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.backend_lxd.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "backend_lxd" {
  launch_configuration = aws_launch_configuration.backend_lxd.name
  min_size             = 1
  max_size             = 1 # Start with 1 instance in the free tier
  desired_capacity     = 1
  vpc_zone_identifier  = aws_subnet.ugly_org_public[*].id

  tag {
    key                 = "Name"
    value               = "BackendLXD"
    propagate_at_launch = true
  }
}

resource "aws_elb" "backend_lxd" {
  name    = "backend-lxd"
  subnets = aws_subnet.ugly_org_public[*].id

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  health_check {
    target              = "HTTP:80/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  instances                   = [aws_autoscaling_group.backend_lxd.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "BackendLXD"
  }
}

output "backend_lxd_elb_dns_name" {
  value = aws_elb.backend_lxd.dns_name
}
