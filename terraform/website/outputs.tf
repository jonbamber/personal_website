output "website_fqdn" {
  value       = "http://${aws_s3_bucket.website.bucket}"
  description = "The Fully Qualified Domain Name (FQDN) for the S3 website."
}
