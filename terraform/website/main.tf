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

resource "aws_s3_bucket" "website" {
  bucket = local.domain_name
  acl    = "private"

  force_destroy = true

  website {
    index_document = local.index_file
    error_document = local.index_file
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

data "aws_iam_policy_document" "website" {
  statement {
    sid       = "AllowCloudFrontGetObject"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    principals {
      identifiers = ["*"]
      type        = "AWS"
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

resource "aws_s3_bucket_object" "index_document" {
  content      = templatefile("${path.module}/../website_files/${local.index_file}", { email_address = var.email_address })
  bucket       = aws_s3_bucket.website.id
  key          = local.index_file
  acl          = "private"
  content_type = "text/html"
}

resource "aws_s3_bucket_object" "profile_picture" {
  source       = "${path.module}/../website_files/${local.profile_picture}"
  bucket       = aws_s3_bucket.website.id
  key          = local.profile_picture
  acl          = "private"
  content_type = "image/png"
  etag         = filemd5("${path.module}/../website_files/${local.profile_picture}")
}

resource "aws_s3_bucket_object" "favicon" {
  source       = "${path.module}/../website_files/${local.favicon}"
  bucket       = aws_s3_bucket.website.id
  key          = local.favicon
  acl          = "private"
  content_type = "image/png"
  etag         = filemd5("${path.module}/../website_files/${local.favicon}")
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
    origin_id   = local.cloudfront_origin_id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  default_root_object = local.index_file
  enabled             = true
  is_ipv6_enabled     = true
  aliases             = [local.domain_name]

  custom_error_response {
    error_caching_min_ttl = 3000
    error_code            = 404
    response_code         = 200
    response_page_path    = "/${local.index_file}"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.cloudfront_origin_id

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
    acm_certificate_arn = data.aws_acm_certificate.website_certificate.arn
    ssl_support_method  = "sni-only"
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
    evaluate_target_health = false
  }
}
