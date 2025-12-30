################################################################################
# Security Group
################################################################################
module "sg" {
  source   = "terraform-aws-modules/security-group/aws"
  for_each = try(local.var.sgs, {})
  create   = try(each.value.create, true)

  name            = try(each.value.name, null)
  use_name_prefix = try(each.value.use_name_prefix, false)
  description     = try(each.value.description, null)
  vpc_id          = try(module.vpc[each.value.vpc_key].vpc_id, null)

  ingress_cidr_blocks = try(each.value.ingress_cidr_blocks, [])
  ingress_rules       = try(each.value.ingress_rules, [])
  egress_cidr_blocks  = try(each.value.egress_cidr_blocks, [])
  egress_rules        = try(each.value.egress_rules, [])

  tags = merge(local.tags, try(each.value.tags, {}))
}

resource "aws_security_group_rule" "this" {
  for_each = try(local.var.sg_rules, {})

  source_security_group_id = try(module.sg[each.value.source_sg_key].security_group_id, null)
  security_group_id        = try(module.sg[each.value.sg_key].security_group_id, null)
  description              = try(each.value.description, null)

  type      = try(each.value.type, null)
  protocol  = try(each.value.protocol, null)
  from_port = try(each.value.from_port, null)
  to_port   = try(each.value.to_port, null)
}

################################################################################
# ACM
################################################################################
module "acm" {
  source             = "terraform-aws-modules/acm/aws"
  for_each           = try(local.var.acms, {})
  create_certificate = try(each.value.create, true)

  # Lấy tên domain từ data source hoặc từ biến trong YAML [cite: 28]
  domain_name = try(data.aws_route53_zone.main[each.value.route53_key].name, each.value.domain_name)
  
  # Tạo Wildcard certificate dựa trên Zone Name [cite: 28]
  subject_alternative_names = [
    "*.${data.aws_route53_zone.main[each.value.route53_key].name}"
  ]

  validation_method    = try(each.value.validation_method, "DNS")
  validate_certificate = true

  # QUAN TRỌNG: Truyền zone_id từ Data Source để module tự tạo record validation 
  zone_id = data.aws_route53_zone.main[each.value.route53_key].zone_id

  tags = merge(local.tags, try(each.value.tags, {}))
}