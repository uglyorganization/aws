
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
