output "valkey_configuration_endpoint" {
  description = "Configuration endpoint of Valkey (ElastiCache)"
  value       = module.valkey_cache.replication_group_configuration_endpoint_address
}

output "valkey_port" {
  description = "Valkey port"
  value       = module.valkey_cache.port
}

