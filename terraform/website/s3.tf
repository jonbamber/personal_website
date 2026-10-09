#=======================================================
# S3 bucket, bucket policy and bucket objects
#=======================================================

# S3 bucket for static website
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
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }

  statement {
    sid       = "EnsureHTTPS"
    effect    = "Deny"
    actions   = ["s3:*"]
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

resource "aws_s3_object" "index_document" {
  content      = templatefile("${path.module}/../website_files/${local.index_file}", { email_address = var.email_address })
  bucket       = aws_s3_bucket.website.id
  key          = local.index_file
  content_type = "text/html"
}

resource "aws_s3_bucket_object" "profile_picture" {
  source       = "${path.module}/../website_files/${local.profile_picture}"
  bucket       = aws_s3_bucket.website.id
  key          = local.profile_picture
  content_type = "image/png"
  etag         = filemd5("${path.module}/../website_files/${local.profile_picture}")
}

resource "aws_s3_bucket_object" "favicon" {
  source       = "${path.module}/../website_files/${local.favicon}"
  bucket       = aws_s3_bucket.website.id
  key          = local.favicon
  content_type = "image/png"
  etag         = filemd5("${path.module}/../website_files/${local.favicon}")
}
