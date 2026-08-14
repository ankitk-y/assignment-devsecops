###############################################################################
# IAM
###############################################################################

# Removed: unused admin (Action="*"/Resource="*") app_node role/policy.

# Cross-account role used by our analytics vendor (Nucleus Analytics) to pull
# aggregated call metadata into their dashboards. Vendor operates in AWS
# account 908212334455.
resource "aws_iam_role" "vendor_analytics" {
  name = "proagent-vendor-analytics"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      # TODO: trusts the vendor's whole account root; narrow once known.
      Principal = { AWS = "arn:aws:iam::908212334455:root" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "vendor_analytics" {
  name = "proagent-vendor-analytics-policy"
  role = aws_iam_role.vendor_analytics.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.call_recordings.arn,
        "${aws_s3_bucket.call_recordings.arn}/*"
      ]
    }]
  })
}

###############################################################################
# CI deploy identity
###############################################################################

# Provides account_id to build the eks:DescribeCluster ARN below.
data "aws_caller_identity" "current" {}

# Role assumed by the CI runner to deploy. Scoped to just the actions the
# pipeline needs.
resource "aws_iam_role" "ci_deployer" {
  name = "proagent-ci-deployer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      # TODO: narrow repo:prodigal/*:* to the exact repo/branch once known.
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:prodigal/*:*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "ci_deployer" {
  name = "proagent-ci-deployer-policy"
  role = aws_iam_role.ci_deployer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      # Only permission deploy.yml actually uses.
      Action   = "eks:DescribeCluster"
      Resource = "arn:aws:eks:ap-south-1:${data.aws_caller_identity.current.account_id}:cluster/proagent-prod"
    }]
  })
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
