variable "domain_name" {
  type = string
}

variable "email_address" {
  type = string
}

locals {
  index_file      = "index.html"
  profile_picture = "profile_picture.png"
  favicon         = "favicon.png"
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
    index_document = local.index_file
    error_document = local.index_file
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

resource "aws_s3_bucket_object" "index_document" {
  content      = templatefile("${path.module}/website/${local.index_file}", { email_address = var.email_address })
  bucket       = aws_s3_bucket.website.id
  key          = local.index_file
  acl          = "public-read"
  content_type = "text/html"
}

resource "aws_s3_bucket_object" "profile_picture" {
  source       = "${path.module}/website/${local.profile_picture}"
  bucket       = aws_s3_bucket.website.id
  key          = local.profile_picture
  acl          = "public-read"
  content_type = "image/png"
  etag         = filemd5("${path.module}/website/${local.profile_picture}")
}

resource "aws_s3_bucket_object" "favicon" {
  source       = "${path.module}/website/${local.favicon}"
  bucket       = aws_s3_bucket.website.id
  key          = local.favicon
  acl          = "public-read"
  content_type = "image/png"
  etag         = filemd5("${path.module}/website/${local.favicon}")
}
