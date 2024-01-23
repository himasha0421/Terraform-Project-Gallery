# define resource provider
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
  }

  user_data = <<-EOT
    #!/bin/bash
    python3 -m http.server 8000
  EOT

}

################# VPC Module ##################

###############################################

module "vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  name            = var.vpc_name #vpc name
  cidr            = var.vpc_cidr #vpc cidr block
  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k)]     #private subnet (secure application)
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 4)] # public subnet (intenet facing)

  # define NAT Gateway (one NAT per AZ)
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

  #define DNS specifications
  enable_dns_hostnames = true
  enable_dns_support   = true

  # define tags
  tags = local.tags

  # VPC Flow Logs (Cloudwatch log group and IAM role will be created)
  enable_flow_log                      = true
  create_flow_log_cloudwatch_log_group = true
  create_flow_log_cloudwatch_iam_role  = true
  flow_log_max_aggregation_interval    = 60

}

################  VPC endpoints ###############

###############################################

module "vpc_endpoints" {
  source = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  vpc_id = module.vpc.vpc_id

  # create security group configs for vpc-endpoints
  create_security_group      = true
  security_group_name_prefix = "${var.vpc_name}-vpc-endpoints-"
  security_group_description = "VPC endpoint security group"
  security_group_rules = {
    ingress_https = {
      description = "HTTPS from VPC"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }
  }

  #define vpc endpoints
  endpoints = {
    s3 = {
      service             = "s3"
      private_dns_enabled = true
      dns_options = {
        private_dns_only_for_inbound_resolver_endpoint = false
      }
      tags = { Name = "s3-vpc-endpoint" }
    }
  }

  #define tags
  tags = merge(local.tags, {
    Project  = "Secret"
    Endpoint = "true"
  })

}


############ auto scaling group ##############

##############################################

module "auto_scaling" {


  source = "terraform-aws-modules/autoscaling/aws"
  name   = var.autoscaling_name

  ################### launch template  #######################
  launch_template_name        = "${var.autoscaling_name}-launch"
  launch_template_description = "vm launch template"
  update_default_version      = true

  # instance configurations
  image_id          = "ami-0c7217cdde317cfec"
  instance_type     = "t2.micro"
  user_data         = base64encode(local.user_data)
  ebs_optimized     = false
  enable_monitoring = true

  # instance storage configs
  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 8
        volume_type           = "gp2"
      }
    },
    {
      device_name = "/dev/sda1"
      no_device   = 1
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 8
        volume_type           = "gp2"
      }
    }
  ]

  # instance type
  instance_market_options = {
    market_type = "spot"
  }

  # network settings
  network_interfaces = [
    {
      delete_on_termination = true
      description           = "eth0"
      device_index          = 0
      security_groups       = [module.security_group.security_group_id]
    }
  ]

  # define resource tags
  tag_specifications = [
    {
      resource_type = "instance"
      tags          = { WhatAmI = "Instance" }
    },
    {
      resource_type = "volume"
      tags          = merge({ WhatAmI = "Volume" })
    },
    {
      resource_type = "spot-instances-request"
      tags          = merge({ WhatAmI = "SpotInstanceRequest" })
    }
  ]

  tags = local.tags

  ############### auto scaling configs ########################
  use_name_prefix     = false
  instance_name       = "VM-scaling-group"
  vpc_zone_identifier = module.vpc.private_subnets

  # traffic source attachment
  create_traffic_source_attachment = true
  traffic_source_identifier        = module.alb.target_groups["vm_asg"].arn
  traffic_source_type              = "elbv2"

  # scaling setup
  ignore_desired_capacity_changes = true
  min_size                        = 0
  max_size                        = 4
  desired_capacity                = 2
  wait_for_capacity_timeout       = 0
  default_instance_warmup         = 300
  health_check_type               = "EC2"

  initial_lifecycle_hooks = [
    {
      name                 = "ExampleStartupLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 60
      lifecycle_transition = "autoscaling:EC2_INSTANCE_LAUNCHING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                 = "ExampleTerminationLifeCycleHook"
      default_result       = "CONTINUE"
      heartbeat_timeout    = 180
      lifecycle_transition = "autoscaling:EC2_INSTANCE_TERMINATING"
      # This could be a rendered data resource
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]


  # define auto scaling schedules
  schedules = {
    night = {
      min_size         = 0
      max_size         = 0
      desired_capacity = 0
      recurrence       = "0 18 * * 1-5" # Mon-Fri in the evening
      time_zone        = "Europe/Rome"
    }

    morning = {
      min_size         = 0
      max_size         = 4
      desired_capacity = 2
      recurrence       = "0 7 * * 1-5" # Mon-Fri in the morning
    }

    go-offline-to-celebrate-new-year = {
      min_size         = 0
      max_size         = 0
      desired_capacity = 0
      start_time       = "2031-12-31T10:00:00Z" # Should be in the future
      end_time         = "2032-01-01T16:00:00Z"
    }
  }

  # Target scaling policy schedule base on average CPU load
  scaling_policies = {
    avg-cpu-policy-greater-than-80 = {
      policy_type               = "TargetTrackingScaling"
      estimated_instance_warmup = 1200
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = 80.0
      }
    }

    # Target scaling based on request count
    request-count-per-target = {
      policy_type               = "TargetTrackingScaling"
      estimated_instance_warmup = 120
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ALBRequestCountPerTarget"
          resource_label         = "${module.alb.arn_suffix}/${module.alb.target_groups["vm_asg"].arn_suffix}"
        }
        target_value = 800
      }
    }

    # scaling out policy
    scale-out = {
      name                      = "scale-out"
      adjustment_type           = "ExactCapacity"
      policy_type               = "StepScaling"
      estimated_instance_warmup = 120
      step_adjustment = [
        {
          scaling_adjustment          = 1
          metric_interval_lower_bound = 0
          metric_interval_upper_bound = 10
        },
        {
          scaling_adjustment          = 2
          metric_interval_lower_bound = 10
        }
      ]
    }

  }
}


############## security group ################

##############################################

module "security_group" {

  source      = "terraform-aws-modules/security-group/aws"
  name        = var.sg_name
  description = "security group with defined rules"

  # attach the vpc
  vpc_id = module.vpc.vpc_id

  # ingress rules for cidr blocks
  ingress_with_cidr_blocks = [
    {
      cidr_blocks = "0.0.0.0/0"
      from_port   = 8000
      to_port     = 8000
      protocol    = "tcp"
      description = "custom python server firewall rule"
    },

    {
      cidr_blocks = "0.0.0.0/0"
      rule        = "http-80-tcp"
      description = "http request firewall rule"
    }

  ]

  # define egress rules
  egress_rules = ["all-all"]

  tags = local.tags
}


############ Application Load Balancer #######

##############################################

module "alb" {

  source = "terraform-aws-modules/alb/aws"
  name   = var.alb_name

  # make it false for testing (prod make it true)
  enable_deletion_protection = false

  # set vpc and public subnets
  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  # attach the security group
  security_groups = [module.security_group.security_group_id]

  # define target groups
  target_groups = {
    vm_asg = {
      backend_protocol                  = "HTTP"
      port                              = 8000
      target_type                       = "instance"
      deregistration_delay              = 5
      load_balancing_cross_zone_enabled = true

      # There's nothing to attach here in this definition.
      # The attachment happens in the ASG module above
      create_attachment = false
    }
  }

  # add traffic listner with target group 
  listeners = {
    vm_http = {
      port     = 80
      protocol = "HTTP"

      # traffic forward
      forward = {
        target_group_key = "vm_asg"
      }
    }
  }

  tags = local.tags

}
