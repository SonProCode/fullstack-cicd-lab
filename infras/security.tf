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

  domain_name               = try(module.route53_zone[each.value.route53_key].name, each.value.domain_name, null)
  subject_alternative_names = try(["*.${module.route53_zone[each.value.route53_key].name}"], ["*.${each.value.domain_name}"], [])
  export                    = try(each.value.export, null)
  validation_method         = try(each.value.validation_method, null)
  key_algorithm             = try(each.value.key_algorithm, null)

  region               = try(each.value.region, null)
  validate_certificate = try(each.value.validate_certificate, true)
  zone_id              = try(module.route53_zone[each.value.route53_key].id, null)

  tags = merge(local.tags, try(each.value.tags, {}))
}
