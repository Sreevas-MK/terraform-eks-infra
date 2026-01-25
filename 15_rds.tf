module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "${var.project_name}-mysql"

  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t4g.micro"
  allocated_storage = 20
  storage_type      = "gp3"

  db_name  = "company"
  username = "appadmin"
  port     = "3306"

  manage_master_user_password = true

  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  publicly_accessible    = false
  multi_az               = false

# max_allocated_storage   = 0
  backup_retention_period = 7
  backup_window           = "03:00-04:00"  

# Time in UTC

  skip_final_snapshot     = true           
# Use false if you need final snapshot
  final_snapshot_identifier = "${var.project_name}-mysql-final-snapshot"

  deletion_protection     = false

  create_db_parameter_group = true
  family                    = "mysql8.0"
  create_db_option_group    = true
  major_engine_version      = "8.0"

  tags = {
    Environment = var.project_environment
    Backup      = "enabled"
  }
}
