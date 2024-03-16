# github backend-lxd

resource "aws_iam_policy" "github_backend_lxd" {
  name        = "github-backend-lxd-ssm"
  description = "Policy granting access to SSM for backend-lxd deployment"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid : "SSMDocumentPermission",
        Effect : "Allow",
        Action : "ssm:SendCommand",
        Resource : "arn:aws:ssm:${var.region}::document/AWS-RunShellScript"
      },
      {
        Sid : "EC2InstancePermission",
        Effect : "Allow",
        Action : [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ],
        Resource : "arn:aws:ec2:${var.region}:${var.AWS_ACCOUNT_ID}:instance/*",
        Condition : {
          StringLike : {
            "ec2:ResourceTag/Name" : "BackendLXD"
          }
        }
      }
    ]
  })
}


resource "aws_iam_role" "github_backend_lxd" {
  name = "github-backend-lxd"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
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
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_backend_lxd_ssm_attach" {
  role       = aws_iam_role.github_backend_lxd.name
  policy_arn = aws_iam_policy.github_backend_lxd.arn
}

# ec2 instance profile

resource "aws_iam_role" "ec2_ssm_role" {
  name = "ec2_ssm_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_managed_core_attachment" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_ssm_instance_profile" {
  name = "ec2_ssm_instance_profile"
  role = aws_iam_role.ec2_ssm_role.name
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

resource "aws_lb" "backend_lxd" {
  name               = "backend-lxd"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.backend_lxd.id]
  subnets            = aws_subnet.ugly_org_public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "BackendLXD"
  }
}

resource "aws_lb_target_group" "backend_lxd" {
  name     = "backend-lxd"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.ugly_org.id

  health_check {
    protocol            = "HTTP"
    path                = "/health"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "BackendLXD"
  }
}

resource "aws_lb_listener" "backend_lxd" {
  load_balancer_arn = aws_lb.backend_lxd.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_lxd.arn
  }
}

resource "aws_launch_template" "backend_lxd" {
  name_prefix   = "backend-lxd-"
  image_id      = "ami-074254c177d57d640"
  instance_type = "t2.micro"

  user_data = base64encode(file("${path.module}/user_data.sh"))

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_ssm_instance_profile.name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.backend_lxd.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "BackendLXD"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "backend_lxd" {
  launch_template {
    id      = aws_launch_template.backend_lxd.id
    version = "$Latest"
  }

  min_size            = 1
  max_size            = 1 # Start with 1 instance in the free tier
  desired_capacity    = 1
  vpc_zone_identifier = aws_subnet.ugly_org_public[*].id

  target_group_arns = [aws_lb_target_group.backend_lxd.arn]

  tag {
    key                 = "Name"
    value               = "BackendLXD"
    propagate_at_launch = true
  }
}

output "backend_lxd_alb_dns_name" {
  value = aws_lb.backend_lxd.dns_name
}