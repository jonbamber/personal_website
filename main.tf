variable "domain_name" {
  type = string
}

variable "email_address" {
  type = string
}

locals {
  index_file           = "index.html"
  profile_picture      = "profile_picture.png"
  favicon              = "favicon.png"
  cloudfront_origin_id = aws_s3_bucket.website.bucket
}

provider "aws" {}

provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

terraform {
  backend "s3" {}
}

data "aws_route53_zone" "website" {
  name = var.domain_name
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

resource "aws_s3_bucket" "website" {
  bucket = var.domain_name
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

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json
}

resource "aws_route53_record" "website" {
  name    = var.domain_name
  zone_id = data.aws_route53_zone.website.zone_id
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_s3_bucket_object" "index_document" {
  content      = templatefile("${path.module}/website/${local.index_file}", { email_address = var.email_address })
  bucket       = aws_s3_bucket.website.id
  key          = local.index_file
  acl          = "private"
  content_type = "text/html"
}

resource "aws_s3_bucket_object" "profile_picture" {
  source       = "${path.module}/website/${local.profile_picture}"
  bucket       = aws_s3_bucket.website.id
  key          = local.profile_picture
  acl          = "private"
  content_type = "image/png"
  etag         = filemd5("${path.module}/website/${local.profile_picture}")
}

resource "aws_s3_bucket_object" "favicon" {
  source       = "${path.module}/website/${local.favicon}"
  bucket       = aws_s3_bucket.website.id
  key          = local.favicon
  acl          = "private"
  content_type = "image/png"
  etag         = filemd5("${path.module}/website/${local.favicon}")
}

resource "aws_acm_certificate" "certificate" {
  provider          = aws.us-east-1 # Necessary for CloudFront use
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  count   = length(aws_acm_certificate.certificate.domain_validation_options)
  name    = element(aws_acm_certificate.certificate.domain_validation_options.*.resource_record_name, count.index)
  type    = element(aws_acm_certificate.certificate.domain_validation_options.*.resource_record_type, count.index)
  zone_id = data.aws_route53_zone.website.zone_id
  records = [element(aws_acm_certificate.certificate.domain_validation_options.*.resource_record_value, count.index)]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "certificate" {
  provider                = aws.us-east-1 # Necessary for CloudFront use
  certificate_arn         = aws_acm_certificate.certificate.arn
  validation_record_fqdns = aws_route53_record.certificate_validation.*.fqdn
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
  aliases             = [var.domain_name]

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
    acm_certificate_arn = aws_acm_certificate.certificate.arn
    ssl_support_method  = "sni-only"
  }
}

output "website_address" {
  value = aws_route53_record.website.fqdn
}
