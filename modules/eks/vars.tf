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

variable "private_subnets" {}

variable "public_subnets" {}