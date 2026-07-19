terraform {
 required_version = ">= 1.12.0"

 required_providers {
 aws = {
 source = "hashicorp/aws"
 version = ">= 6.0, < 7.0"
 }
 }
}

# AWS Global Accelerator is a global service whose control-plane API is hosted in
# us-west-2. This module needs only ONE provider (not a second-region pair like
# CloudFront/ACM), so it relies on standard provider inheritance and declares no
# provider {} block and no configuration_aliases. If the caller's default region
# is not us-west-2, pass a us-west-2 provider alias:
#
# module "global_accelerator" {
# source = "git::https://github.com/microsoftexpert/tf_mod_aws_global_accelerator?ref=v1.0.0"
# providers = { aws = aws.us_west_2 }
#...
# }
