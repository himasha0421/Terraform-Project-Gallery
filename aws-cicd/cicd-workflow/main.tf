# set the deafult aws region
provider "aws" {
  region = var.region
}

# aws default data block to fetch availablity zones
data "aws_availability_zones" "available" {}

# local variable definition
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    creator  = "terraform"
    maintain = "demerzelAI"
    author   = "Himasha"
    project  = "cicd-workflow"
  }

}


################## VPC ######################
# create vpc module for the codebuild project

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.vpc-name
  cidr = var.vpc-cidr
  azs  = local.azs
  # define private/public subnets
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc-cidr, 8, k)]     #private subnet (secure application)
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc-cidr, 8, k + 4)] #public subnet (intenet facing)

  # set NAT configuration
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  # DNS configuration
  enable_dns_hostnames = true
  enable_dns_support   = true

  # define tags
  tags = local.tags

}

################# Security Group ###############
# create security group to manage the traffic into instances

module "security_group" {
  source      = "terraform-aws-modules/security-group/aws"
  name        = var.sg-name
  description = var.sg-description

  # attach the vpc to the sg
  vpc_id = module.vpc.vpc_id

  # define ingress rules
  ingress_with_cidr_blocks = [

    # python ingress
    {
      cidr_blocks = "0.0.0.0/0"
      from_port   = 5000
      to_port     = 5000
      protocol    = "tcp"
      description = "python flask server ingress rule"

    },
    # http traffic ingress
    {
      cidr_blocks = "0.0.0.0/0"
      rule        = "http-80-tcp"
      description = "http request firewall rule"
    }
  ]

  #define outbound traffic rules
  egress_rules = ["all-all"]

  tags = local.tags
}


################# Code Build Project #################
# create codebuild resources

resource "aws_codebuild_project" "cicd-workflow" {
  name          = var.codebuild-name
  description   = var.codebuild-description
  build_timeout = 5
  service_role  = aws_iam_role.codebuild-role.arn

  #define build artifacts (if build stage create some package artifacts)
  artifacts {
    type = "NO_ARTIFACTS"
  }

  # storage for codebuild project cache
  cache {
    type     = "S3"
    location = aws_s3_bucket.meta-store.bucket
  }

  # configure the execusion enviroment
  environment {

    # setup docker image types 
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

  }

  # configure vpc configuration for the enviroment
  vpc_config {
    vpc_id = module.vpc.vpc_id
    subnets = setunion(
      module.vpc.private_subnets
    )
    security_group_ids = [
      module.security_group.security_group_id
    ]
  }

  # define git configuration
  source {
    type            = "GITHUB"
    location        = "https://github.com/himasha0421/Me"
    git_clone_depth = 1

    git_submodules_config {
      fetch_submodules = true
    }
  }

  # git branch
  source_version = "main"

  logs_config {
    cloudwatch_logs {
      group_name  = "cicd-log-group"
      stream_name = "cicd-log-stream"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.meta-store.id}/build-log"
    }
  }

  tags = merge(local.tags, {
    Enviroment : "Test"
  })
}


############# Code Pipeline #################

# create codepipeline resource

resource "aws_codepipeline" "cicd-pipeline" {

  name     = "cicd-workflow-pipeline"
  role_arn = aws_iam_role.codepipeline-role.arn

  # artifact store
  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.meta-store.bucket
  }

  # source stage (source repo check)
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      # git codestart connection
      configuration = {
        ConnectionArn    = data.aws_codestarconnections_connection.cicd-connection.arn
        FullRepositoryId = "himasha0421/Me"
        BranchName       = "main"
      }

    }


  }

  # build the project and push docker to ECR
  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      # setup configuration
      configuration = {
        ProjectName = aws_codebuild_project.cicd-workflow.name
      }
    }
  }

}
