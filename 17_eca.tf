module "valkey_cache" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 1.10.0"

  replication_group_id = "${var.project_name}-valkey"

  engine         = "valkey"
  engine_version = "8.2"
  node_type      = "cache.t4g.micro"
  port           = 6379

  cluster_mode_enabled       = true
  num_node_groups            = 1
  replicas_per_node_group    = 0
  automatic_failover_enabled = true
  multi_az_enabled           = false

  vpc_id              = module.vpc.vpc_id
  create_subnet_group = false
  subnet_group_name   = module.vpc.elasticache_subnet_group_name

  create_security_group = false
  security_group_ids    = [aws_security_group.redis_sg.id]

  create_parameter_group = true
  parameter_group_family = "valkey8"

  apply_immediately        = true
  snapshot_retention_limit = 0 # No backups

  tags = {
    Environment = var.project_environment
  }
}
