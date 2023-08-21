module "management-us-west-2" {
  source             = "./modules/eks"
  region             = "us-west-2"
  environment        = terraform.workspace
  cluster_name       = "${terraform.workspace}-management"
  iam_cluster_admin  = aws_iam_role.eks_cluster_admin
  iam_cluster_role   = aws_iam_role.eks_cluster_role
  iam_node_role      = aws_iam_role.eks_node_role
  iam_karpenter_role = aws_iam_role.karpenter
  iam_ebs_csi_role   = aws_iam_role.ebs_csi
  public_subnets     = [aws_subnet.tlb-default-pub-a.id,aws_subnet.tlb-default-pub-b.id]
  private_subnets    = [aws_subnet.tlb-default-priv-a.id,aws_subnet.tlb-default-priv-b.id]
}


resource "aws_kinesis_firehose_delivery_stream" "covid_data_stream" {
  name        = "${var.environment}_covid_data_stream"
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn        = aws_iam_role.firehose_role.arn
    bucket_arn      = var.s3_bucket_arn
    prefix          = "${var.environment}/data/covid_data_stream"
    buffer_interval = 60
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "production/covid_data_stream"
      log_stream_name = "firehose"
    }
  }
}

data "aws_iam_policy_document" "firehose_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["firehose.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}



resource "aws_iam_role" "firehose_role" {
  name               = "firehose_test_role"
  assume_role_policy = data.aws_iam_policy_document.firehose_assume_role.json

  inline_policy {
    name = "s3_write"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:AbortMultipartUpload",
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:ListBucketMultipartUploads",
            "s3:PutObject"
          ]
          Resource = [
            var.s3_bucket_arn,
            "${var.s3_bucket_arn}/*"
          ]
        },
      ]
    })
  }

  inline_policy {
    name = "kinesis_read"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "kinesis:DescribeStream",
            "kinesis:GetShardIterator",
            "kinesis:GetRecords",
            "kinesis:ListShards"
          ]
          # This is because I'm dumb.  I'm sure I can attach a role policy after creation but I'm in a hurry :P
          Resource = [
            "arn:aws:firehose:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:deliverystream/${var.environment}_covid_data_stream"
          ]
        },
      ]
    })
  }
}
