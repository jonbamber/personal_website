#=======================================================
# Sensitive variables passed from environment
#=======================================================

variable "domain_name" {
  type = string
}

variable "subdomain" {
  type    = string
  default = ""
}

variable "email_address" {
  type = string
}

#=======================================================
# Local variables
#=======================================================

locals {
  index_file           = "index.html"
  profile_picture      = "profile_picture.png"
  favicon              = "favicon.png"
  cloudfront_origin_id = aws_s3_bucket.website.bucket
  domain_name          = var.subdomain == "" ? var.domain_name : join(".", [var.subdomain, var.domain_name])
}

#=======================================================
# Provider details
# NB: us-east-1 is required for ACM for CloudFront
#=======================================================

terraform {
  required_version = "~> 0.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {}

provider "aws" {
  alias  = "acm"
  region = "us-east-1"
}

#=======================================================
# Back end configuration
# NB: bucket, key & region passed from CircleCI
#=======================================================

terraform {
  backend "s3" {}
}

#=======================================================
# S3 bucket, bucket policy and bucket objects
#=======================================================

# S3 Bucket for Static
resource "aws_s3_bucket" "website" {
  bucket        = local.domain_name
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = local.index_file
  }

  error_document {
    key = local.index_file
  }
}

data "aws_iam_policy_document" "website" {
  statement {
    sid       = "AllowCloudFrontGetObject"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
  }

  statement {
    sid       = "EnsureHTTPS"
    effect    = "Deny"
    actions   = ["*"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json
}

# Index file
resource "aws_s3_object" "index_document" {
  content      = templatefile("${path.module}/../website_files/${local.index_file}", { email_address = var.email_address })
  bucket       = aws_s3_bucket.website.id
  key          = local.index_file
  content_type = "text/html"
}

# Other website files
resource "aws_s3_object" "website_files" {
  for_each = { for website_file in fileset("${path.module}/../website_files/", "**/*") : website_file => "${path.module}/../website_files/${website_file}"
    if website_file != local.index_file
  }

  bucket = aws_s3_bucket.website.id
  key    = each.value
  source = each.value
  content_type = lookup({
    "html" = "text/html",
    "css"  = "text/css",
    "js"   = "application/javascript",
    "json" = "application/json",
    "png"  = "image/png",
    "jpg"  = "image/jpeg",
    "jpeg" = "image/jpeg",
    "gif"  = "image/gif",
    "svg"  = "image/svg+xml"
  }, reverse(split(".", basename(each.value)))[0], "application/octet-stream")

  etag = filemd5(each.value)
}

#=======================================================
# CloudFront distribution
#=======================================================

data "aws_acm_certificate" "website_certificate" {
  provider = aws.acm
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {}

resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.website.bucket

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  default_root_object = local.index_file
  enabled             = true
  is_ipv6_enabled     = true
  aliases             = [local.domain_name]
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.website.bucket
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn      = data.aws_acm_certificate.website_certificate.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

#=======================================================
# Route 53 record
#=======================================================

data "aws_route53_zone" "website" {
  name = var.domain_name
}

resource "aws_route53_record" "website" {
  name    = local.domain_name
  zone_id = data.aws_route53_zone.website.zone_id
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = true
  }
}
