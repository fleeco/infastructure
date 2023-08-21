#############################################################
############# (>^_^)> CLUSTER ROLE <(^_^<) ##################
#############################################################
resource "aws_iam_role" "eks_cluster_role" {
  name = "${terraform.workspace}-eks-cluster-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "EKSClusterAssumeRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "eks.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ]
}


#############################################################
########## (>^_^)> NODE_GROUP ROLE <(^_^<) ##################
#############################################################
resource "aws_iam_role" "eks_node_role" {
  name = "${terraform.workspace}-eks-node-role"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "EKSWorkerAssumeRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      },
      {
        "Sid" : "EKSFargateAssumeRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "eks-fargate-pods.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      },
      {
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::939067023032:role/kube-cross-account-ecr-access"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })

  # TODO: Lockdown permissions

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess",
    "arn:aws:iam::aws:policy/AmazonKinesisFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess",
    "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  ]
}

#############################################################
########## (>^_^)> KARPENTER ROLES <(^_^<) ##################
#############################################################
data "aws_iam_policy_document" "karpenter" {
  dynamic "statement" {
    for_each = local.oidc_providers
    content {
      actions = ["sts:AssumeRoleWithWebIdentity"]
      effect  = "Allow"

      condition {
        test     = "StringEquals"
        variable = "${replace(statement.value.url, "https://", "")}:sub"
        values   = ["system:serviceaccount:karpenter:karpenter"]
      }

      principals {
        identifiers = [statement.value.arn]
        type        = "Federated"
      }
    }
  }
}

resource "aws_iam_role" "karpenter" {
  name = "${terraform.workspace}-eks-karpenter-irsa-role"

  assume_role_policy = data.aws_iam_policy_document.karpenter.json

  inline_policy {
    name = "${terraform.workspace}-eks-karpenter-irsa-policy"

    policy = jsonencode({
      "Statement" : [
        {
          "Action" : [
            "ssm:GetParameter",
            "pricing:GetProducts",
            "iam:PassRole",
            "ec2:RunInstances",
            "ec2:DescribeSubnets",
            "ec2:DescribeSpotPriceHistory",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeLaunchTemplates",
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceTypes",
            "ec2:DescribeInstanceTypeOfferings",
            "ec2:DescribeImages",
            "ec2:DescribeAvailabilityZones",
            "ec2:DeleteLaunchTemplate",
            "ec2:CreateTags",
            "ec2:CreateLaunchTemplate",
            "ec2:CreateFleet"
          ],
          "Effect" : "Allow",
          "Resource" : "*",
          "Sid" : "Karpenter"
        },
        {
          "Action" : "ec2:TerminateInstances",
          "Condition" : {
            "StringLike" : {
              "ec2:ResourceTag/Name" : "*karpenter*"
            }
          },
          "Effect" : "Allow",
          "Resource" : "*",
          "Sid" : "ConditionalEC2Termination"
        }
      ],
      "Version" : "2012-10-17"
    })
  }
}

resource "aws_iam_instance_profile" "karpenter" {
  name = aws_iam_role.karpenter.name
  role = aws_iam_role.eks_node_role.name
}

#############################################################
########## (>^_^)> ARGOCD_MANAGER  <(^_^<) ##################
#############################################################
data "aws_iam_policy_document" "argocd-manager" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:AssumeRole"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(local.oidc_providers.management-us-west-2.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:argocd:argocd-application-controller"]
    }

    principals {
      identifiers = [local.oidc_providers.management-us-west-2.arn]
      type        = "Federated"
    }
  }
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      type        = "AWS"
    }
  }
}


#############################################################
############ (>^_^)> EBS_CSI ROLES <(^_^<) ##################
#############################################################
data "aws_iam_policy_document" "ebs_csi" {
  dynamic "statement" {
    for_each = local.oidc_providers
    content {
      actions = ["sts:AssumeRoleWithWebIdentity", "sts:AssumeRole"]
      effect  = "Allow"

      condition {
        test     = "StringEquals"
        variable = "${replace(statement.value.url, "https://", "")}:sub"
        values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
      }

      principals {
        identifiers = [statement.value.arn]
        type        = "Federated"
      }
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name                = "${terraform.workspace}-eks-ebs-csi-irsa-role"
  assume_role_policy  = data.aws_iam_policy_document.ebs_csi.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
}

#############################################################
####### (>^_^)> ARGO_CD_VAULT_CSI ROLES <(^_^<) #############
#############################################################
data "aws_iam_policy_document" "argo-cd-argocd-repo-server" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity", "sts:AssumeRole"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(local.oidc_providers.management-us-west-2.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:argo-cd-argocd-repo-server"]
    }

    principals {
      identifiers = [local.oidc_providers.management-us-west-2.arn]
      type        = "Federated"
    }
  }
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
      type        = "AWS"
    }
  }
}

resource "aws_iam_role" "argo-cd-argocd-repo-server" {
  name                = "${terraform.workspace}-eks-ebs-argo-cd-argocd-repo-server"
  assume_role_policy  = data.aws_iam_policy_document.argo-cd-argocd-repo-server.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/SecretsManagerReadWrite"]
}

#############################################################
########## (>^_^)> CLUSTER ADMIN ROLE <(^_^<) ###############
#############################################################
resource "aws_iam_role" "eks_cluster_admin" {
  name = "${terraform.workspace}-cluster-admin"

  assume_role_policy = data.aws_iam_policy_document.argocd-manager.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  ]

  inline_policy {
    name = "${terraform.workspace}-eks-console-viewer-policy"

    policy = jsonencode({
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "eks:ListFargateProfiles",
            "eks:DescribeNodegroup",
            "eks:ListNodegroups",
            "eks:ListUpdates",
            "eks:AccessKubernetesApi",
            "eks:ListAddons",
            "eks:DescribeCluster",
            "eks:DescribeAddonVersions",
            "eks:ListClusters",
            "eks:ListIdentityProviderConfigs",
            "iam:ListRoles"
          ],
          "Resource" : "*"
        }
      ],
      "Version" : "2012-10-17"
    })
  }
}