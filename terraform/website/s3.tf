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

resource "aws_s3_object" "website_files" {
  for_each = {
    for website_file in fileset(local.website_files_dir, "**/*") :
    website_file => {
      is_template = endswith(website_file, ".tftpl")
      key         = trimsuffix(website_file, ".tftpl")
      source      = "${local.website_files_dir}/${website_file}"
      file_type   = reverse(split(".", trimsuffix(website_file, ".tftpl")))[0]
    }
  }

  bucket = aws_s3_bucket.website.id
  key    = each.value.key

  # Look up MIME type - default to arbitrary binary data
  content_type = lookup(
    local.mime_type_map,
    each.value.file_type,
    "application/octet-stream"
  )

  # Required only for templated files
  content = each.value.is_template ? templatefile(
    each.value.source,
    local.common_template_vars
  ) : null

  # Required only for non-templated files
  source = each.value.is_template ? null : each.value.source
  etag   = each.value.is_template ? null : filemd5(each.value.source)
}
