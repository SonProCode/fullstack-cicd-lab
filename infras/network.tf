################################################################################
# VPC
################################################################################
module "vpc" {
  source     = "terraform-aws-modules/vpc/aws"
  for_each   = try(local.var.vpcs, {})
  create_vpc = try(each.value.create, true)

  name             = try(each.value.name, null)
  cidr             = try(each.value.cidr, null)
  enable_ipv6      = try(each.value.enable_ipv6, null)
  instance_tenancy = try(each.value.instance_tenancy, null)

  azs              = try(each.value.azs, [])
  public_subnets   = try(each.value.public_subnets, [])
  private_subnets  = try(each.value.private_subnets, [])
  database_subnets = try(each.value.database_subnets, [])

  enable_nat_gateway     = try(each.value.enable_nat_gateway, null)
  single_nat_gateway     = try(each.value.single_nat_gateway, null)
  one_nat_gateway_per_az = try(each.value.one_nat_gateway_per_az, null)

  enable_dns_hostnames         = try(each.value.enable_dns_hostnames, null)
  enable_dns_support           = try(each.value.enable_dns_support, null)
  create_database_subnet_group = try(each.value.create_database_subnet_group, false)

  tags = merge(local.tags, try(each.value.tags, {}))
}

################################################################################
# ALB
################################################################################
module "alb" {
  source   = "terraform-aws-modules/alb/aws"
  for_each = try(local.var.albs, {})
  create   = try(each.value.create, true)

  load_balancer_type = try(each.value.load_balancer_type, null)
  name               = try(each.value.name, null)
  internal           = try(each.value.internal, null)
  ip_address_type    = try(each.value.ip_address_type, null)

  vpc_id     = try(module.vpc[each.value.vpc_key].vpc_id, null)
  ipam_pools = try(each.value.ipam_pools, {})
  subnets    = try(each.value.internal == true ? module.vpc[each.value.vpc_key].private_subnets : module.vpc[each.value.vpc_key].public_subnets, [])

  security_groups            = try([module.sg[each.value.sg_key].security_group_id], [])
  create_security_group      = try(each.value.create_security_group, false)
  enable_deletion_protection = try(each.value.enable_deletion_protection, false)

  listeners = try({ 
    for k, v in each.value.listeners : k => merge(v, {
      # Thay vì gọi trực tiếp, ta dùng lookup. 
      # Nếu ACM chưa có, nó sẽ trả về null thay vì làm "hỏng" cả vòng lặp for_each.
      certificate_arn = try(v.protocol, "") == "HTTPS" ? lookup(module.acm, v.acm_key, { acm_certificate_arn = null }).acm_certificate_arn : null
    }) 
  }, {})
  
  target_groups = try({ for k, v in each.value.target_groups : k => merge(v, {
    vpc_id = try(module.vpc[v.vpc_key].vpc_id, null)
  }) }, {})

  tags = merge(local.tags, try(each.value.tags, {}))
}

################################################################################
# Route 53
################################################################################
module "route53_zone" {
  source   = "terraform-aws-modules/route53/aws"
  for_each = try(local.var.route53_zones, {})
  create   = try(each.value.create, true)

  name          = try(each.value.name, null)
  comment       = try(each.value.comment, null)
  force_destroy = try(each.value.force_destroy, true)
  tags          = try(each.value.tags, {})
}

resource "aws_route53_record" "this" {
  for_each = {
    for item in flatten([
      for r_key, r_val in try(local.var.route53_records, {}) : [
        for k, v in r_val.records : {
          key         = "${r_key}.${k}"
          route53_key = r_val.route53_key
          name        = r_val.name
          type        = v.type
          alb_key     = v.alb_key
        }
      ]
    ]) : item.key => item
  }

  zone_id = module.route53_zone[each.value.route53_key].id
  name    = each.value.name
  type    = each.value.type

  alias {
    name                   = module.alb[each.value.alb_key].dns_name
    zone_id                = module.alb[each.value.alb_key].zone_id
    evaluate_target_health = true
  }
}