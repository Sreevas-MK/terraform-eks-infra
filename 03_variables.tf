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
  default     = "arn:aws:route53:::hostedzone/Z05823322O3AF5KJRMOWS"
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
  default     = "https://github.com/Sreevas-MK/employees-data-app-eks-helm.git"
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
  default     = "app.sreevasmk.online"
}

variable "certificate_id" {
  description = "The UUID of the certificate"
  type        = string
  default     = "77e2c37c-1194-449a-a349-79d6db76bb68"
}

variable "alb_group_name" {
  description = "ALB group name"
  type        = string
  default     = "eks-alb"
}

variable "grafana_url" {
  description = "The external URL for ArgoCD"
  type        = string
  default     = "grafana.sreevasmk.online"
}

variable "argocd_url" {
  description = "The external URL for ArgoCD"
  type        = string
  default     = "argocd.sreevasmk.online"
}

variable "my_ip_cidr" {
  default = "200.69.21.162/32"
}


variable "github_username" {
  default = "Sreevas-MK"
}

variable "github_repo" {
  default = "terraform-eks-infra"
}
