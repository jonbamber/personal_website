# personal_website

This repository contains code for a personal static website hosted in S3.

The code defines:

* A private S3 bucket with website files
* A validated ACM certificate
* A CloudFront distribution pointing to the website bucket
* A Route 53 record pointing to the CloudFront distribution

## Usage

The following environment variables are used:

|||
|--|--|
| `AWS_ACCESS_KEY_ID` | AWS access key ID |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key |
| `AWS_REGION` | AWS region |
| `TERRAFORM_STATE_BUCKET` | S3 bucket for Terraform state file (object prefix is set using the repository name) |
| `WEBSITE` | Domain name for the website (and S3 bucket name), e.g. `example.com` |
| `EMAIL` | Email address inserted into website HTML |

A CircleCI configuration file allows the automatic deployment of infrastructure upon a commit being pushed to GitHub
(environment variables set under a CircleCI context `AWS`); however, infrastructure can be deployed manually through:

```
terraform init
terraform apply --auto-approve
```
