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

variable "vpc_cidr_block" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "route53_hosted_zone_arn" {
  description = "route53_hosted_zone_arns"
  type        = string
  default     = "arn:aws:route53:::hostedzone/Z040348811KTWIYFFYOIF"
}


variable "eks_node_instance_type" {
  description = "Instance type for eks node"
  type        = string
  default     = "t3.medium"
}


variable "eks_node_ami_type" {
  description = "AMI type for eks node"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "eks_node_disk_size" {
  description = "Disk size (in GB) for EKS worker nodes"
  type        = number
  default     = 20
}

variable "app_repo_url" {
  description = "Application repo url"
  type        = string
  default     = "https://github.com/Sreevas-MK/employees-data-app-rds-eca-eks.git"
}

variable "app_repo_path" {
  description = "Application repo path"
  type        = string
  default     = "."
}

variable "app_namespace" {
  description = "Application namespace"
  type        = string
  default     = "flask-mysql-redis-app"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "flask-mysql-redis-app"
}

variable "app_host" {
  description = "Application hostname"
  type        = string
  default     = "app.sreevasmk.in"
}

variable "certificate_arn" {
  description = "certificate arn at ACM"
  type        = string
  default     = "arn:aws:acm:ap-south-1:337909748081:certificate/e2f7cebe-713c-49cc-9cf4-79683a52256e"
}

variable "alb_group_name" {
  description = "ALB group name"
  type        = string
  default     = "eks-alb"
}

variable "argocd_url" {
  description = "The external URL for ArgoCD"
  type        = string
  default     = "https://argocd.sreevasmk.in"
}

variable "my_ip_cidr" {
  default = "200.69.21.162/32"
}
