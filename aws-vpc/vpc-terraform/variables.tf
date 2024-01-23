variable "region" {
  description = "aws resource region"
}

variable "vpc_cidr" {
  description = "vpc cidr block"
  default     = "10.1.0.0/16"
}

variable "vpc_name" {
  description = "vpc name"
}

variable "autoscaling_name" {
  description = "auto scaling group name"
}

variable "sg_name" {
  description = "security group name"
}

variable "alb_name" {
  description = "application load balancer name"
}
