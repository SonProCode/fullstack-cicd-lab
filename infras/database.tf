
################################################################################
# RDS
################################################################################
data "aws_kms_key" "rds_kms_key_id" {
  for_each = try(local.var.rds_databases, {})
  key_id   = try(each.value.kms_key_id, null)
}

module "rds" {
  source             = "terraform-aws-modules/rds/aws"
  for_each           = try(local.var.rds_databases, {})
  create_db_instance = try(each.value.create, true)

  engine                   = try(each.value.engine, null)
  engine_version           = try(each.value.engine_version, null)
  engine_lifecycle_support = try(each.value.engine_lifecycle_support, null)
  multi_az                 = try(each.value.multi_az, null)

  identifier                    = try(each.value.identifier, null)
  username                      = try(each.value.username, null)
  manage_master_user_password   = try(each.value.manage_master_user_password, null)
  # master_user_secret_kms_key_id = try(data.aws_kms_key.secrets_manager_kms_key_id[each.key].arn, null)
  instance_class                = try(each.value.instance_class, null)

  storage_type          = try(each.value.storage_type, null)
  allocated_storage     = try(each.value.allocated_storage, null)
  iops                  = try(each.value.iops, null)
  storage_throughput    = try(each.value.storage_throughput, null)
  max_allocated_storage = try(each.value.max_allocated_storage, null)

  network_type                    = try(each.value.network_type, null)
  db_subnet_group_name            = try(each.value.db_subnet_group_name, null)
  db_subnet_group_use_name_prefix = try(each.value.db_subnet_group_use_name_prefix, false)
  db_subnet_group_description     = try(each.value.db_subnet_group_description, null)
  subnet_ids                      = try(slice(module.vpc[each.value.vpc_key].database_subnets, 2, 4), [])
  db_subnet_group_tags            = merge(local.tags, try(each.value.db_subnet_group_tags, {}))

  publicly_accessible    = try(each.value.publicly_accessible, null)
  vpc_security_group_ids = try([module.sg[each.value.sg_key].security_group_id], [])
  availability_zone      = try(each.value.availability_zone, null)
  ca_cert_identifier     = try(each.value.ca_cert_identifier, null)
  port                   = try(each.value.port, null)

  iam_database_authentication_enabled   = try(each.value.iam_database_authentication_enabled, null)
  performance_insights_enabled          = try(each.value.performance_insights_enabled, false)
  performance_insights_retention_period = try(each.value.performance_insights_retention_period, null)
  performance_insights_kms_key_id       = try(data.aws_kms_key.rds_kms_key_id[each.key].arn, null)

  monitoring_interval             = try(each.value.monitoring_interval, 0)
  monitoring_role_name            = try(each.value.monitoring_role_name, null)
  monitoring_role_description     = try(each.value.monitoring_role_description, null)
  enabled_cloudwatch_logs_exports = try(each.value.enabled_cloudwatch_logs_exports, [])

  db_name                         = try(each.value.db_name, null)
  family                          = try(each.value.family, null)
  parameter_group_use_name_prefix = try(each.value.parameter_group_use_name_prefix, false)
  major_engine_version            = try(each.value.major_engine_version, null)

  backup_retention_period = try(each.value.backup_retention_period, null)
  backup_window           = try(each.value.backup_window, null)
  copy_tags_to_snapshot   = try(each.value.copy_tags_to_snapshot, null)
  storage_encrypted       = try(each.value.storage_encrypted, null)
  kms_key_id              = try(data.aws_kms_key.rds_kms_key_id[each.key].arn, null)

  auto_minor_version_upgrade = try(each.value.auto_minor_version_upgrade, null)
  maintenance_window         = try(each.value.maintenance_window, null)
  deletion_protection        = try(each.value.deletion_protection, null)
  snapshot_identifier        = try(each.value.snapshot_identifier, null)

  create_db_subnet_group      = try(each.value.create_db_subnet_group, true)
  create_monitoring_role      = try(each.value.create_monitoring_role, true)
  create_cloudwatch_log_group = try(each.value.create_cloudwatch_log_group, true)

  tags = merge(local.tags, try(each.value.tags, {}))
}
