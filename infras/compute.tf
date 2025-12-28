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
                  valueFrom = module.rds[s.rds_secret_key].db_instance_master_user_secret_arn
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

      # --- Load Balancer ---
      # Logic: Nếu có khai báo target_group_key trong YAML thì mới tạo block load_balancer
      load_balancer = can(service_config.target_group_key) ? {
        service = {
            # Lưu ý: Bạn cần thay thế `aws_lb_target_group` bên dưới bằng resource thực tế hoặc module lookup của bạn
            # Ví dụ: module.alb.target_groups[service_config.target_group_key].arn
            target_group_arn = try(module.alb[service_config.alb_key].target_groups[service_config.target_group_key].arn, null)            
            container_name   = service_name
            container_port   = try(service_config.container_port, 80)
        }
      } : {}

      # --- Network ---
      # Tự động lấy Private Subnet từ module VPC dựa vào vpc_key trong YAML
      subnet_ids = try(module.vpc[each.value.vpc_key].private_subnets, [])

      # --- Security Group Rules ---
      security_group_ids = [for sg_key in try(service_config.security_group_keys, []) : module.sg[sg_key].security_group_id]
    }
  }

  tags = merge(local.tags, try(each.value.tags, {}))
}