################################################################################
# ECS MODULE
################################################################################
resource "aws_service_discovery_private_dns_namespace" "this" {
  for_each = try(local.var.namespaces, {})

  name        = try(each.value.name, each.key)
  description = "Service Connect namespace managed by Terraform"
  # Mapping động vpc_id thông qua vpc_key
  vpc         = module.vpc[each.value.vpc_key].vpc_id 
}

module "ecs" {
  source   = "terraform-aws-modules/ecs/aws"
  for_each = try(local.var.ecs_clusters, {})

  cluster_name = try(each.value.name, "ecs-cluster")

  # Cấu hình Capacity Provider
  default_capacity_provider_strategy = try(each.value.default_capacity_provider_strategy, {})

  # ====================================================
  # SERVICES LOOP
  # ====================================================
  services = {
    for service_name, service_config in try(each.value.services, {}) : service_name => {
      
      cpu    = try(service_config.cpu, 512)
      memory = try(service_config.memory, 1024)

      # --- Container Definition ---
      container_definitions = {
            (service_name) = {
              image     = try(service_config.image, "nginx:latest")
              essential = true
              readonlyRootFilesystem = false
              portMappings = [{
                  name          = try(service_config.port_name, "http")
                  containerPort = try(service_config.container_port, 80)
                  protocol      = "tcp"
              }]

              # --- XỬ LÝ BIẾN MÔI TRƯỜNG ĐỘNG ---
              environment = [
                  for env in try(service_config.environment, []) : {
                      name  = env.name
                      # Sử dụng replace lồng nhau để thay thế các placeholder
                     value = replace(
                        replace(
                          env.value, 
                          "<RDS-ENDPOINT>", 
                          try(module.rds[service_config.rds_reference].db_instance_address, "")
                        ), 
                        "ALB_DNS_PLACEHOLDER", 
                        try(module.alb[service_config.alb_key].dns_name, "")
                      )
                  }
              ]

              secrets = [
                  for s in try(service_config.secrets, []) : {
                    name      = s.name 
                    valueFrom = "${module.rds[s.rds_secret_key].db_instance_master_user_secret_arn}:password::"
                  }
              ]
              enable_cloudwatch_logging = true
        }
      }

      # --- Service Connect ---
      service_connect_configuration = can(service_config.service_connect) ? {
        namespace = try(
          aws_service_discovery_private_dns_namespace.this[service_config.service_connect.namespace_key].arn,
          null
        )
        service = [{
          port_name      = try(service_config.port_name, "http")
          discovery_name = try(service_config.service_connect.discovery_name, service_name)
          client_alias = {
            dns_name = try(service_config.service_connect.client_alias_dns, service_name)
            port     = try(service_config.service_connect.client_alias_port, 80)
          }
        }]
      } : null
      
      task_exec_iam_role_policies = can(service_config.secrets) ? {
        "ReadRdsSecret" = aws_iam_policy.ecs_secrets_policy["${each.key}.${service_name}"].arn
      } : {}

      # --- Load Balancer ---
      load_balancer = can(service_config.target_group_key) ? {
        service = {
            target_group_arn = try(module.alb[service_config.alb_key].target_groups[service_config.target_group_key].arn, null)            
            container_name   = service_name
            container_port   = try(service_config.container_port, 80)
        }
      } : {}
      # --- Network ---
      subnet_ids = try(module.vpc[each.value.vpc_key].private_subnets, [])

      # --- Security Group Rules ---
      security_group_ids = [for sg_key in try(service_config.security_group_keys, []) : module.sg[sg_key].security_group_id]
    }
  }

  tags = merge(local.tags, try(each.value.tags, {}))
}


#===========================================================
locals {
  # Lọc ra danh sách phẳng các service thực sự có khai báo block 'secrets'
  services_needing_secrets = flatten([
    for cluster_key, cluster_config in try(local.var.ecs_clusters, {}) : [
      for service_name, service_config in try(cluster_config.services, {}) : {
        cluster_key  = cluster_key
        service_name = service_name
        secrets      = service_config.secrets
      }
      if can(service_config.secrets) && length(try(service_config.secrets, [])) > 0
    ]
  ])
}

resource "aws_iam_policy" "ecs_secrets_policy" {
  for_each = {
    for s in local.services_needing_secrets : "${s.cluster_key}.${s.service_name}" => s
  }

  name        = "${var.tags.environment}-${each.value.service_name}-secrets-policy"
  description = "Allow ECS to fetch RDS secrets from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["secretsmanager:GetSecretValue"]
        Effect   = "Allow"
        # Lấy ARN động từ module RDS thông qua key rds_secret_key trong YAML
        Resource = [
          for s in each.value.secrets : module.rds[s.rds_secret_key].db_instance_master_user_secret_arn
        ]
      },
      {
        Action   = ["kms:Decrypt"]
        Effect   = "Allow"
        Resource = ["*"]
      }
    ]
  })
}