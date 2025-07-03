#=======================================================
# Route 53 record
#=======================================================

data "aws_route53_zone" "website" {
  name = var.domain_name
}

resource "aws_route53_record" "website" {
  name    = local.domain_name
  zone_id = data.aws_route53_zone.website.zone_id
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}
