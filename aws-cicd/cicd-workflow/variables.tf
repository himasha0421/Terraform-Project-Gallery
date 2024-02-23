variable "region" {
  description = "default aws region"
}

variable "vpc-name" {
  description = "vpc identifier"
}

variable "vpc-cidr" {
  description = "vpc deafult cidr block"
  default     = "10.1.0.0/16"
}

variable "codebuild-name" {
  description = "code build project name"
}

variable "codebuild-description" {
  description = "description about the codebuild project"
}

variable "sg-name" {
  description = "security group name"
}

variable "sg-description" {
  description = "security group description"
}
