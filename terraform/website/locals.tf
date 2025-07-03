locals {
  index_file      = "index.html"
  profile_picture = "profile_picture.png"
  favicon         = "favicon.png"
  domain_name     = var.subdomain == "" ? var.domain_name : join(".", [var.subdomain, var.domain_name])
}
