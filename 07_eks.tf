module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                        = "${var.project_name}-cluster"
  kubernetes_version          = "1.31"
  enable_irsa                 = true
  create_cloudwatch_log_group = false
  # Set true if log group already exists

  addons = {
    eks-pod-identity-agent = {
      before_compute = true
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
  }

  endpoint_public_access                   = true
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets


  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    default = {
      ami_type       = var.eks_node_ami_type
      instance_types = [var.eks_node_instance_type]

      key_name  = aws_key_pair.ssh_auth_key.id
      disk_size = var.eks_node_disk_size


      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }

  tags = {
    Environment = var.project_environment
    Terraform   = "true"
  }
}
