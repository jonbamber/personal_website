variable "domain_name" {
  type = string
  description = "Domain for the static website."
}

variable "subdomain" {
  type    = string
  description = "Subdomain for the static website for e.g. test use."
}

variable "email_address" {
  type = string
  description = "Email address to insert into the website HTML for contact details."
}
