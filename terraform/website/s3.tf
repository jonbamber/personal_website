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
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }

    # condition {
    #   test     = "StringEquals"
    #   variable = "AWS:SourceArn"
    #   values   = [aws_cloudfront_distribution.website.arn]
    # }
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

resource "aws_s3_bucket_public_access_block" "my_bucket_public_access_block" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
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
