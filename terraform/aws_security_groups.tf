locals {
  security_groups = {
    cluster = {
      description = "Firewall rules for every node in the cluster"

      ingress_rules = {
        kubelet = {
          network_scope = "control-plane"
          port_range    = [10250]
          ip_protocol   = "tcp"
          description   = "Allow kubelet API access from control-plane nodes"
        }

        ssh = {
          network_scope = "public"
          port_range    = [22]
          ip_protocol   = "tcp"
          description   = "Allow SSH access from any source"
        }

        flannel-vxlan = {
          network_scope = "cluster"
          port_range    = [8472]
          ip_protocol   = "udp"
          description   = "Allow flannel VXLAN overlay traffic between nodes"
        }
      }

      egress_rules = {
        internet-access = {
          description   = "Allow all outbound traffic to any destination"
          network_scope = "public"
        }
      }
    }

    control-plane = {
      description = "Firewall rules for control-plane nodes"

      ingress_rules = {
        api-server = {
          network_scope = "public"
          port_range    = [6443]
          ip_protocol   = "tcp"
          description   = "Allow Kubernetes API server access from any source"
        }

        etcd = {
          network_scope = "control-plane"
          port_range    = [2379, 2380]
          ip_protocol   = "tcp"
          description   = "Allow etcd client and peer communication between control-plane nodes"
        }

        kube-scheduler = {
          network_scope = "control-plane"
          port_range    = [10251]
          ip_protocol   = "tcp"
          description   = "Allow kube-scheduler health checks between control-plane nodes"
        }

        kube-controller-manager = {
          network_scope = "control-plane"
          port_range    = [10252]
          ip_protocol   = "tcp"
          description   = "Allow kube-controller-manager health checks between control-plane nodes"
        }
      }
    }

    worker = {
      description = "Firewall rules for worker nodes"

      ingress_rules = {
        node-port-services = {
          network_scope = "public"
          port_range    = [30000, 32767]
          ip_protocol   = "tcp"
          description   = "Allow NodePort service traffic from any source"
        }
      }
    }
  }
}

resource "aws_security_group" "this" {
  for_each = local.security_groups

  name        = format("kubeadm-lab-%s", each.key)
  description = each.value.description
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

  cidr_ipv4                    = each.value.network_scope == "public" ? "0.0.0.0/0" : null
  referenced_security_group_id = each.value.network_scope != "public" ? aws_security_group.this[each.value.network_scope].id : null

  ip_protocol = try(each.value.ip_protocol, "tcp")

  from_port = each.value.port_range[0]
  to_port   = each.value.port_range[length(each.value.port_range) - 1]

  tags = {
    Name = each.value.rule_key
  }
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

  cidr_ipv4                    = each.value.network_scope == "public" ? "0.0.0.0/0" : null
  referenced_security_group_id = each.value.network_scope != "public" ? aws_security_group.this[each.value.network_scope].id : null

  ip_protocol = -1

  tags = {
    Name = each.value.rule_key
  }
}
