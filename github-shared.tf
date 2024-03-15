# github shared

resource "aws_s3_bucket" "github-shared" {
  bucket = "github-shared-${random_id.random.hex}"

  tags = {
    Name        = "github-shared"
    Environment = "Dev"
  }
}

resource "aws_iam_policy" "github_shared" {
  name        = "github-shared"
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

resource "aws_iam_role" "github_shared" {
  name               = "github-shared"
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

resource "aws_iam_policy_attachment" "github_shared" {
  name       = "github-shared"
  policy_arn = aws_iam_policy.github_shared.arn
  roles      = [aws_iam_role.github_shared.name]
}
