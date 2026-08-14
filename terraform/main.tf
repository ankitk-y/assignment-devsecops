###############################################################################
# proAgent staging platform - core infrastructure
#
# NOTE: state is currently local. `terraform apply` runs from laptops today.
###############################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # (no backend block configured)
}

provider "aws" {
  region     = "ap-south-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

###############################################################################
# Networking
###############################################################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = { Name = "proagent-staging" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-south-1a"
  tags = { Name = "proagent-staging-public" }
}

# Public-facing ALB for the borrower-facing voice gateway.
# Handles TLS termination for inbound calls from the telephony provider.
resource "aws_security_group" "alb" {
  name   = "proagent-alb"
  vpc_id = aws_vpc.main.id

  ingress {
    description = "Public HTTPS to the voice gateway ALB"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "proagent-alb" }
}

# Security group for the application nodes / bastion.
resource "aws_security_group" "app_nodes" {
  name   = "proagent-app-nodes"
  vpc_id = aws_vpc.main.id

  # TODO: no admin CIDR is evidenced; SSH left open until one is known.
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Scoped to the VPC CIDR; was 0.0.0.0/0 despite being labeled "internal".
  ingress {
    description = "All internal service ports"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "proagent-app-nodes" }

  # Ops tweaks ingress by hand during incidents; ignore drift so apply
  # doesn't revert it. NOTE: this also blocks the ingress fix above from
  # actually applying until resolved.
  lifecycle {
    ignore_changes = [ingress]
  }
}

###############################################################################
# Call-recording storage
#
# Stores raw borrower call recordings + transcripts consumed by the
# intent-intelligence pipeline.
###############################################################################

resource "aws_s3_bucket" "call_recordings" {
  bucket = "proagent-staging-call-recordings"
  tags   = { Name = "call-recordings" }
}

resource "aws_s3_bucket_acl" "call_recordings" {
  bucket = aws_s3_bucket.call_recordings.id
  acl    = "private"
}

###############################################################################
# Primary datastore
###############################################################################

resource "aws_db_instance" "primary" {
  identifier          = "proagent-staging-db"
  engine              = "postgres"
  engine_version      = "15.4"
  instance_class      = "db.t3.medium"
  allocated_storage   = 50
  db_name             = "proagent"
  username            = "proagent_admin"
  password            = var.db_password
  publicly_accessible = false
  skip_final_snapshot = false

  # 7 days is a minimal-cost baseline, not a benchmarked RPO.
  backup_retention_period = 7
  deletion_protection     = true

  vpc_security_group_ids = [aws_security_group.app_nodes.id]
}

###############################################################################
# Transcripts storage (redacted transcripts + derived intent metadata)
#
# Hardened per the last security review: private ACL + KMS encryption.
###############################################################################

resource "aws_kms_key" "transcripts" {
  description         = "Encrypts the transcripts bucket"
  enable_key_rotation = true

  # Removed AllowDecrypt statement (Principal="*"); no consumer evidenced.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "Root"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::111122223333:root" }
        Action    = "kms:*"
        Resource  = "*"
      }
    ]
  })
}

resource "aws_s3_bucket" "transcripts" {
  bucket = "proagent-staging-transcripts"
  tags   = { Name = "transcripts" }
}

resource "aws_s3_bucket_acl" "transcripts" {
  bucket = aws_s3_bucket.transcripts.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "transcripts" {
  bucket = aws_s3_bucket.transcripts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.transcripts.arn
    }
  }
}

# Removed: aws_s3_bucket_policy.transcripts granted s3:GetObject to
# Principal="*" (public read); no consumer evidenced.
