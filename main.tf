variable "domain_name" {
  type = string
}

provider "aws" {}

terraform {
  backend "s3" {}
}

data "aws_route53_zone" "website" {
  name = var.domain_name
}

data "aws_iam_policy_document" "website" {
  statement {
    actions = [
      "s3:GetObject"
    ]
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    resources = [
      "arn:aws:s3:::${var.domain_name}/*"
    ]
  }
}

resource "aws_s3_bucket" "website" {
  bucket = var.domain_name
  acl    = "public-read"

  force_destroy = true

  website {
    index_document = "index.html"
    error_document = "index.html"
  }

}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json
}

resource "aws_route53_record" "website" {
  zone_id = data.aws_route53_zone.website.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_s3_bucket.website.website_domain
    zone_id                = aws_s3_bucket.website.hosted_zone_id
    evaluate_target_health = false
  }
}