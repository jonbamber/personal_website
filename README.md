# personal_website

This repository contains code for a personal static website hosted in S3.

The code defines an S3 bucket with

* `public-read` ACL
* public `GetObject` permissions on associate S3 IAM policy
* Route 53 record

## Usage

The following environment variables are required:

|||
|--|--|
| `AWS_ACCESS_KEY_ID` | AWS access key ID |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key |
| `AWS_REGION` | AWS region |
| `TERRAFORM_STATE_BUCKET` | S3 bucket for Terraform state file (object prefix is set using the repository name) |
| `TF_VAR_domain_name` | Domain name for the website (and S3 bucket name), e.g. `example.com` |

A CircleCI configuration file allows the automatic deployment of infrastructure upon a commit being pushed to GitHub
(environment variables set under a CircleCI context `AWS`); however, infrastructure can be deployed manually through:

```
terraform init
terraform apply --auto-approve
```
