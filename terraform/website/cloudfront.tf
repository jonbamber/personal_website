#=======================================================
# CloudFront distribution
#=======================================================

data "aws_acm_certificate" "website_certificate" {
  provider = aws.acm
  domain   = var.domain_name
  statuses = ["ISSUED"]
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {}

resource "aws_cloudfront_origin_access_control" "default" {
  name                              = local.domain_name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "website" {
  origin {
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.website.bucket
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
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
