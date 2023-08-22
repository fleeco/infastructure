# # We install Karpenter using terraform / helm since there are so many
# # dependencies on knowing what the fuck profiles / etc are being used. If there
# # is a way to do this with argo for ease of upgrading / etc that'd be great.
# resource "helm_release" "karpenter" {
#   namespace        = "karpenter"
#   create_namespace = true

#   name       = "karpenter"
#   repository = "oci://public.ecr.aws/karpenter"
#   chart      = "karpenter"
#   version    = "v0.30.0"

#   set {
#     name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
#     value = var.iam_karpenter_role.arn
#   }

#   set {
#     name  = "settings.aws.clusterName"
#     value = aws_eks_cluster.this.name
#   }

#   set {
#     name  = "settings.aws.clusterEndpoint"
#     value = aws_eks_cluster.this.endpoint
#   }

#   set {
#     name  = "settings.aws.defaultInstanceProfile"
#     value = var.iam_node_role.name
#   }

#   depends_on = [
#     kubectl_manifest.aws_auth
#   ]
# }