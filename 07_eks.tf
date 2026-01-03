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
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
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

  eks_managed_node_groups = {
    default = {
      ami_type       = var.eks_node_ami_type
      instance_types = [var.eks_node_instance_type]

      key_name          = aws_key_pair.ssh_auth_key.id
      disk_size         = var.eks_node_disk_size

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }

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

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix      = "ebs-csi-driver-"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Environment = var.project_environment
  }
}

module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix                       = "load-balancer-controller-"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller-sa"]
    }
  }

  tags = {
    Environment = var.project_environment
  }
}

module "external_dns_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix              = "external-dns-"
  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = [var.route53_hosted_zone_arn]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-dns:external-dns"]
    }
  }

  tags = {
    Environment = var.project_environment
  }
}


module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.23.0"

  depends_on = [
    module.eks.eks_managed_node_groups
  ]

  eks_addons = {
    coredns = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent                 = true
      service_account_role_arn    = module.ebs_csi_driver_irsa.iam_role_arn
      resolve_conflicts_on_create = "OVERWRITE"
    }
  }

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    set = [
      {
        name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
        value = module.lb_controller_irsa.iam_role_arn
      },
      {
        name  = "serviceAccount.name"
        value = "aws-load-balancer-controller-sa"
      },
#       {
#         name  = "serviceAccount.create"
#         value = "true"
#       },
      {
        name  = "vpcId"
        value = module.vpc.vpc_id
      }
    ]
  }

  enable_metrics_server = true

  enable_external_dns = true
  external_dns = {
    set = [{
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.external_dns_irsa.iam_role_arn
    }]
  }

  tags = {
    Environment = var.project_environment
  }
}

resource "aws_security_group_rule" "bastion_to_api" {
  description              = "Bastion to EKS API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks.cluster_security_group_id
  source_security_group_id = aws_security_group.bastion.id
}

resource "aws_security_group_rule" "bastion_to_node_ssh" {
  description              = "Bastion SSH to worker nodes"
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = aws_security_group.bastion.id
}
