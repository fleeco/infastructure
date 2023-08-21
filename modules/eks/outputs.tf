output "eks_cluster" {
  value = aws_eks_cluster.this
}

output "openid_connect_provider" {
  value = aws_iam_openid_connect_provider.this
}