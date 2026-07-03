locals {
  security_groups = {
    node-firewall = {
      description = "Firewall rules for every node in the cluster"
      ingress_rules = {
        kubelet = { network_scope = "vpc", port_range = [10250], description = "Allow kubelet API access from within the VPC" }
        ssh     = { network_scope = "any", port_range = [22], description = "Allow SSH access from any source" }
      }
      egress_rules = {
        internet = { network_scope = "any", description = "Allow all outbound traffic to any destination" }
      }
    }
    control-plane-firewall = {
      description = "Firewall rules for control-plane nodes"
      ingress_rules = {
        api-server         = { network_scope = "any", port_range = [6443], description = "Allow Kubernetes API server access from any source" }
        etcd               = { network_scope = "vpc", port_range = [2379, 2380], description = "Allow etcd client and peer communication within the VPC" }
        scheduler          = { network_scope = "vpc", port_range = [10251], description = "Allow kube-scheduler health checks within the VPC" }
        controller-manager = { network_scope = "vpc", port_range = [10252], description = "Allow kube-controller-manager health checks within the VPC" }
      }
    }
    worker-firewall = {
      description = "Firewall rules for worker nodes"
      ingress_rules = {
        services = { network_scope = "any", port_range = [30000, 32767], description = "Allow NodePort service traffic from any source" }
      }
    }
  }
}

locals {
  network_scope_to_cidr_ipv4 = {
    "any" = "0.0.0.0/0"
    "vpc" = aws_default_vpc.this.cidr_block
  }
}

resource "aws_security_group" "this" {
  for_each = local.security_groups

  name        = "kube-formation-${each.key}"
  description = each.value.description
  vpc_id      = aws_default_vpc.this.id
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = merge([
    for sg_key, sg_value in local.security_groups : {
      for rule_key, rule_value in try(sg_value.ingress_rules, {}) :
      "${sg_key}:${rule_key}" => merge(rule_value, { sg_key = sg_key, rule_key = rule_key }
      )
    }
  ]...)

  description       = each.value.description
  security_group_id = aws_security_group.this[each.value.sg_key].id
  cidr_ipv4         = local.network_scope_to_cidr_ipv4[each.value.network_scope]
  ip_protocol       = try(each.value.ip_protocol, "tcp")
  from_port         = each.value.port_range[0]
  to_port           = each.value.port_range[length(each.value.port_range) - 1]

  tags = { Name = each.value.rule_key }
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = merge([
    for sg_key, sg_value in local.security_groups : {
      for rule_key, rule_value in try(sg_value.egress_rules, {}) :
      "${sg_key}:${rule_key}" => merge(rule_value, { sg_key = sg_key, rule_key = rule_key }
      )
    }
  ]...)

  description       = each.value.description
  security_group_id = aws_security_group.this[each.value.sg_key].id
  cidr_ipv4         = local.network_scope_to_cidr_ipv4[each.value.network_scope]
  ip_protocol       = try(each.value.ip_protocol, -1)

  tags = { Name = each.value.rule_key }
}

locals {
  control_plane_security_group_ids = [
    aws_security_group.this["node-firewall"].id,
    aws_security_group.this["control-plane-firewall"].id,
  ]
  worker_security_group_ids = [
    aws_security_group.this["node-firewall"].id,
    aws_security_group.this["worker-firewall"].id,
  ]
}
