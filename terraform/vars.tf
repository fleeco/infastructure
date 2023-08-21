variable "environment" {
  type    = string
  default = "production"
}

variable "s3_bucket_arn" {
  type    = string
  default = "arn:aws:s3:::thelatestlead"
}

# data "aws_ssm_parameter" "github_ssh_key" {
#   name = "/env/p0/kubekilla/ssh"
# }

locals {
  oidc_providers = {
    "management-us-west-2" : module.management-us-west-2.openid_connect_provider,
    # "delivery-us-east-1" : module.delivery-us-east-1.openid_connect_provider,
    # "delivery-us-west-2" : module.delivery-us-west-2.openid_connect_provider
    # "delivery-eu-west-1" : module.delivery-eu-west-1.openid_connect_provider,
    # "delivery-ap-southeast-2" : module.delivery-ap-southeast-2.openid_connect_provider
  }
  clusters = {
    # "del-use-1" : module.delivery-us-east-1.eks_cluster,
    # "del-usw-2" : module.delivery-us-west-2.eks_cluster,
    # "del-euw-1" : module.delivery-eu-west-1.eks_cluster,
    # "del-aps-2" : module.delivery-ap-southeast-2.eks_cluster
  }
}