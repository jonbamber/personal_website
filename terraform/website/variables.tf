#=======================================================
# Sensitive variables passed from environment
#=======================================================

variable "domain_name" {
  type = string
}

variable "subdomain" {
  type    = string
  default = ""
}

variable "email_address" {
  type = string
}
