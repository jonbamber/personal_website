#=======================================================
# Sensitive variables passed from environment
#=======================================================

variable "domain_name" {
  type = string
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
# Hosted zone
# NB: created by Route53 Registrar through console
#=======================================================

data "aws_route53_zone" "website" {
  name = var.domain_name
}

#=======================================================
# ACM certificate validation
#=======================================================

resource "aws_acm_certificate" "website_certificate" {
  provider                  = aws.acm # Necessary for CloudFront use
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "website_certificate_validation" {
  for_each = {
    for domain_validation_option in aws_acm_certificate.website_certificate.domain_validation_options : domain_validation_option.domain_name => {
      name   = domain_validation_option.resource_record_name
      record = domain_validation_option.resource_record_value
      type   = domain_validation_option.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  zone_id         = data.aws_route53_zone.website.zone_id
  ttl             = 60
}

resource "aws_acm_certificate_validation" "website_certificate_validation" {
  provider        = aws.acm # Necessary for CloudFront use
  certificate_arn = aws_acm_certificate.website_certificate.arn

  validation_record_fqdns = [
    for record in aws_route53_record.website_certificate_validation : record.fqdn
  ]

  timeouts {
    create = "10m"
  }
}
