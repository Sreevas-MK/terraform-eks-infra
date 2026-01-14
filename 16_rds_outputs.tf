output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = module.db.db_instance_endpoint
}

output "rds_port" {
  description = "RDS MySQL port"
  value       = module.db.db_instance_port
}

output "rds_identifier" {
  description = "RDS instance identifier"
  value       = module.db.db_instance_identifier
}
