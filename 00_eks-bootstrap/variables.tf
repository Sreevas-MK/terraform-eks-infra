variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "eks-infra"
}

variable "project_environment" {
  description = "Project Environment"
  type        = string
  default     = "Development"
}

variable "s3_bucket_name" {
  description = "s3 bucket name"
  type        = string
  default     = "eks-project-terraform-state-0001"
}

