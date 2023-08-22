module "management-us-west-2" {
  source             = "./modules/eks"
  region             = "us-west-2"
  environment        = var.environment
  cluster_name       = "${var.environment}-management"
  iam_cluster_admin  = aws_iam_role.eks_cluster_admin
  iam_cluster_role   = aws_iam_role.eks_cluster_role
  iam_node_role      = aws_iam_role.eks_node_role
  iam_karpenter_role = aws_iam_role.karpenter
  iam_ebs_csi_role   = aws_iam_role.ebs_csi
  public_subnets     = aws_subnet.public[*].id
  private_subnets    = aws_subnet.private[*].id
}

