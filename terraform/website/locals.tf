#=======================================================
# Local variables
#=======================================================

locals {
  domain_name = var.subdomain == "" ? var.domain_name : join(".", [var.subdomain, var.domain_name])

  website_files_dir = "${path.module}/website_files"
  index_file        = "index.html"

  # Passed to any/all templates
  common_template_vars = {
    email_address = var.email_address
  }

  # Used to map file extension to S3 object content type
  mime_type_map = {
    "html" = "text/html",
    "css"  = "text/css",
    "js"   = "application/javascript",
    "json" = "application/json",
    "png"  = "image/png",
    "jpg"  = "image/jpeg",
    "jpeg" = "image/jpeg",
    "gif"  = "image/gif",
    "svg"  = "image/svg+xml"
  }
}
