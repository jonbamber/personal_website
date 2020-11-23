# personal_website

This repo contains code for a personal static website hosted in S3.

The code defines an S3 bucket with
* `public-read` ACL
* public `GetObject` permissions on associate S3 IAM policy
* Route 53 record

## Usage

Infrastructure is deployed manually through:
```
terraform init
terraform apply --auto-approve
```
