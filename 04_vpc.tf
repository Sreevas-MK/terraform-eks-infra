data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  depends_on = [null_resource.destruction_dependencies]

  name = var.project_name
  cidr = var.vpc_cidr_block


  ## This ensures you ALWAYS take exactly 3 zones, even in regions with 6. It is because we have only 3 subnets.

  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  public_subnets                  = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets                 = ["10.0.11.0/24", "10.0.12.0/24", "10.0.13.0/24"]
  create_database_subnet_group    = true
  database_subnets                = ["10.0.21.0/24", "10.0.22.0/24", "10.0.23.0/24"]
  create_elasticache_subnet_group = true
  elasticache_subnets             = ["10.0.31.0/24", "10.0.32.0/24", "10.0.33.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Terraform                                           = "true"
    Environment                                         = var.project_environment
    "kubernetes.io/cluster/${var.project_name}-cluster" = "shared"
  }
}
