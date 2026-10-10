#=======================================================
# Provider details
# NB: us-east-1 is required for ACM for CloudFront
#=======================================================

terraform {
  required_version = "~> 1.16.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {}

provider "aws" {
  alias  = "acm"
  region = "us-east-1"
}

#=======================================================
# Back end configuration
# NB: bucket, key & region passed from CircleCI
#=======================================================

terraform {
  backend "s3" {}
}
