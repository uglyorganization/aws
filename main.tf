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

resource "random_id" "random" {
  byte_length = 8
}

# GITHUB SHARED S3

resource "aws_s3_bucket" "github-shared" {
  bucket = "github-shared-${random_id.random.hex}"

  tags = {
    Name        = "GithubSharedBucket"
    Environment = "Dev"
  }
}

resource "aws_iam_policy" "github_shared_policy" {
  name        = "github-shared-policy"
  description = "Policy granting full access to the github-shared bucket"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:*",
        ],
        Resource = [
          aws_s3_bucket.github-shared.arn,
          "${aws_s3_bucket.github-shared.arn}/*",
        ],
      },
    ],
  })
}

resource "aws_iam_role" "github_shared_role" {
  name               = "github-shared-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${var.AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:uglyorganization/*"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "github_shared_policy_attachment" {
  name       = "github-shared-policy-attachment"
  policy_arn = aws_iam_policy.github_shared_policy.arn
  roles      = [aws_iam_role.github_shared_role.name]
}

output "github_shared_role_arn" {
  value = aws_iam_role.github_shared_role.arn
}

# FRONTEND AND CDN

resource "random_id" "frontend" {
  byte_length = 8
}

resource "aws_s3_bucket" "frontend" {
  bucket = "frontend-${random_id.frontend.hex}"

  tags = {
    Name        = "FrontendBucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_public_access_block" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend.id
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "PublicReadGetObject",
          "Effect" : "Allow",
          "Principal" : "*",
          "Action" : "s3:GetObject",
          "Resource" : "arn:aws:s3:::${aws_s3_bucket.frontend.id}/*"
        }
      ]
    }
  )
}

resource "aws_cloudfront_distribution" "frontend_distribution" {
  enabled         = true
  is_ipv6_enabled = true

  origin {
    domain_name = aws_s3_bucket_website_configuration.frontend.website_endpoint
    origin_id   = aws_s3_bucket.frontend.bucket_regional_domain_name

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_keepalive_timeout = 5
      origin_protocol_policy   = "http-only"
      origin_read_timeout      = 30
      origin_ssl_protocols = [
        "TLSv1.2",
      ]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  default_cache_behavior {
    cache_policy_id        = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.frontend.bucket_regional_domain_name
  }
}

output "website_url" {
  description = "Website URL (HTTPS)"
  value       = aws_cloudfront_distribution.frontend_distribution.domain_name
}

output "s3_url" {
  description = "S3 hosting URL (HTTP)"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}
