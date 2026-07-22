###############################################################################
# IAM
###############################################################################

# Role attached to the application nodes.
resource "aws_iam_role" "app_node" {
  name = "proagent-app-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "app_node" {
  name = "proagent-app-node-policy"
  role = aws_iam_role.app_node.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}

# Cross-account role used by our analytics vendor (Nucleus Analytics) to pull
# aggregated call metadata into their dashboards. Vendor operates in AWS
# account 908212334455.
resource "aws_iam_role" "vendor_analytics" {
  name = "proagent-vendor-analytics"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
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
      Action = [
        "ec2:RunInstances",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "eks:DescribeCluster",
        "iam:PassRole"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
