variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "argocd_install" {
  type    = bool
  default = false
}

variable "argocd_clusters" {
  type    = map(any)
  default = {}
}

variable "iam_cluster_admin" {}

variable "iam_cluster_role" {}

variable "iam_node_role" {}

variable "iam_ebs_csi_role" {}

variable "iam_karpenter_role" {}

data "aws_ssm_parameter" "private_subnets" {
  name = "/env/p0/vpc/subnets/private"
}

data "aws_ssm_parameter" "vpc_id" {
  name = "/env/p0/vpc/id"
}