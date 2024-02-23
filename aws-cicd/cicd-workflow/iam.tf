################ Code Build IAM Role ##################
# create data block to hold the role meta data

data "aws_iam_policy_document" "iam-role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# attach the role data to the IAM role

resource "aws_iam_role" "codebuild-role" {
  name               = "codebuild-service-role"
  assume_role_policy = data.aws_iam_policy_document.iam-role.json
}

# define data block to hold the policies needed to bind with role

data "aws_iam_policy_document" "iam-policies" {

  # s3 policy
  statement {
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.meta-store.arn, "${aws_s3_bucket.meta-store.arn}/*"]
  }

  #ecr policy
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:DescribeRepositories",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
      "ecr:GetLifecyclePolicy",
      "ecr:GetLifecyclePolicyPreview",
      "ecr:ListTagsForResource",
      "ecr:DescribeImageScanFindings",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = ["*"]
  }

  # system-manager policy (access parameter strore)
  statement {
    effect = "Allow"
    actions = [
      "ssm:Describe*",
      "ssm:Get*",
      "ssm:List*"
    ]
    resources = ["*"]
  }

  # cloud watch log policy
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["*"]
  }

  # add vpc , sg policies
  statement {
    effect = "Allow"

    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
    ]

    resources = ["*"]
  }

  # ec2 resource provisioning policy
  statement {
    effect    = "Allow"
    actions   = ["ec2:CreateNetworkInterfacePermission"]
    resources = ["arn:aws:ec2:us-east-1:630210676530:network-interface/*"]

    condition {
      test     = "StringLike"
      variable = "ec2:Subnet"

      values = setunion(module.vpc.public_subnet_arns, module.vpc.private_subnet_arns)
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values   = ["codebuild.amazonaws.com"]
    }
  }

}

# attach the policies to the service-role
resource "aws_iam_role_policy" "role-policies" {
  role   = aws_iam_role.codebuild-role.name
  policy = data.aws_iam_policy_document.iam-policies.json
}


################## Code Pipeline IAM Role ###############

# data block for the codepipeline configs

data "aws_iam_policy_document" "pipeline-data" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# create service role with above data block

resource "aws_iam_role" "codepipeline-role" {
  name               = "codepipeline-role"
  assume_role_policy = data.aws_iam_policy_document.pipeline-data.json
}


# define data block with pipeline policies

data "aws_iam_policy_document" "pipeline-policy" {

  # s3 policy
  statement {
    effect  = "Allow"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.meta-store.arn,
      "${aws_s3_bucket.meta-store.arn}/*"
    ]
  }

  # codebuild policy
  statement {
    effect = "Allow"

    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]

    resources = ["*"]
  }

  # codestar policy (github connection)
  statement {
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = [data.aws_codestarconnections_connection.cicd-connection.arn]
  }
}

# attach the policy to the role

resource "aws_iam_role_policy" "codepipeline-policy" {
  name   = "codepipeline-policy"
  role   = aws_iam_role.codepipeline-role.id
  policy = data.aws_iam_policy_document.pipeline-policy.json
}
