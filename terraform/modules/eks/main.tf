resource "aws_eks_cluster" "this" {
  name                      = var.cluster_name
  version                   = "1.27"
  role_arn                  = var.iam_cluster_role.arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    subnet_ids = var.private_subnets
  }

  timeouts {
    create = "1h30m"
    update = "2h"
    delete = "20m"
  }
}

# resource "aws_eks_node_group" "this" {
#   cluster_name    = aws_eks_cluster.this.name
#   node_group_name = "${aws_eks_cluster.this.name}-node-group"
#   node_role_arn   = var.iam_node_role.arn
#   subnet_ids      = var.private_subnets
#   instance_types  = ["c4.large"]

#   scaling_config {
#     desired_size = 4
#     max_size     = 5
#     min_size     = 1
#   }

#   lifecycle {
#     ignore_changes = [scaling_config[0].desired_size]
#   }
# }


resource "aws_eks_fargate_profile" "system" {
  cluster_name           = aws_eks_cluster.this.name 
  fargate_profile_name   = "fargate-system"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = var.private_subnets

  selector {
    namespace = "kube-system"
  }
}

resource "aws_eks_fargate_profile" "default" {
  cluster_name           = aws_eks_cluster.this.name 
  fargate_profile_name   = "fargate-default"
  pod_execution_role_arn = aws_iam_role.fargate.arn
  subnet_ids             = var.private_subnets

  selector {
    namespace = "default"
  }
}

resource "aws_iam_role" "fargate" {
  name = "eks-fargate-profile-example"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "example-AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate.name
}

resource "aws_eks_addon" "aws-ebs-csi-driver" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = var.iam_ebs_csi_role.arn
  timeouts {
    create = "10m"
    update = "2h"
    delete = "20m"
  }
  depends_on = [
    aws_eks_fargate_profile.system
  ]
}


resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"
  timeouts {
    create = "10m"
    update = "2h"
    delete = "20m"
  }
  depends_on = [
    aws_eks_fargate_profile.system
  ]
}

resource "aws_eks_addon" "kube-proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"

  depends_on = [
    aws_eks_fargate_profile.system
  ]
}

resource "aws_eks_addon" "vpc-cni" {
  cluster_name      = aws_eks_cluster.this.name
  resolve_conflicts = "OVERWRITE"
  addon_name        = "vpc-cni"
  depends_on = [
    aws_eks_fargate_profile.system
  ]
}

## This sets up OIDC authentication
data "tls_certificate" "this" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = data.tls_certificate.this.certificates[*].sha1_fingerprint
  url             = data.tls_certificate.this.url
}

# This IS CONFUSING. So when you create an EKS cluster the only user who is
# authenticated with the server IS THE USER THAT CREATED IT. In order for
# anybody from RC to access it they need to assume the p0-cluster-admin role,
# which can be done when you do update-kubeconfig (it's in the README).
locals {
  aws_auth_roles = concat(
    [
      ## This is the default config AWS provides
      {
        rolearn  = var.iam_node_role.arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      },
      ## Allows all cluster admins to use the cluster
      {
        rolearn  = var.iam_cluster_admin.arn
        username = "cluster-admins"
        groups   = ["system:masters"]
      }
    ]
  )
}

# This feels ratchet but is actually the way to get roles to authenticate with
# the cluster. Go figure.
resource "kubectl_manifest" "aws_auth" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/managed-by: Terraform
  name: aws-auth
  namespace: kube-system
data:
  mapAccounts: |
    []
  mapRoles: |
    ${indent(4, yamlencode(local.aws_auth_roles))}
  mapUsers: |
    []
YAML

  depends_on = [
    aws_eks_cluster.this,
    aws_eks_fargate_profile.system
  ]
}