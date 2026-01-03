module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${var.project_name}-cluster"
  kubernetes_version = "1.31"
  enable_irsa        = true
  create_cloudwatch_log_group = false
  # Set true if log group already exists

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  tags = {
    Environment = var.project_environment
    Terraform   = "true"
  }
}

