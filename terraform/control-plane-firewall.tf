resource "aws_security_group" "control_plane_firewall" {
  name        = "control_plane_firewall"
  description = "Firewall rules for control-plane node"
  vpc_id      = aws_default_vpc.default.id

  # tags = {
  #   Name = "control_plane_firewall"
  # }
}

resource "aws_vpc_security_group_ingress_rule" "api_server" {
  security_group_id = aws_security_group.control_plane_firewall.id
  cidr_ipv4         = aws_default_vpc.default.cidr_block
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
}

resource "aws_vpc_security_group_ingress_rule" "etcd" {
  security_group_id = aws_security_group.control_plane_firewall.id
  cidr_ipv4         = aws_default_vpc.default.cidr_block
  ip_protocol       = "tcp"
  from_port         = 2379
  to_port           = 2379
}

resource "aws_vpc_security_group_ingress_rule" "scheduler" {
  security_group_id = aws_security_group.control_plane_firewall.id
  cidr_ipv4         = aws_default_vpc.default.cidr_block
  ip_protocol       = "tcp"
  from_port         = 10251
  to_port           = 10251
}

resource "aws_vpc_security_group_ingress_rule" "controller_manager" {
  security_group_id = aws_security_group.control_plane_firewall.id
  cidr_ipv4         = aws_default_vpc.default.cidr_block
  ip_protocol       = "tcp"
  from_port         = 10252
  to_port           = 10252
}
