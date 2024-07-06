resource "aws_security_group" "node_firewall" {
  name        = "node_firewall"
  description = "Firewall rules for every node in the cluster"
  vpc_id      = aws_default_vpc.default.id

  # tags = {
  #   Name = "node_firewall"
  # }
}

resource "aws_vpc_security_group_ingress_rule" "kubelet" {
  security_group_id = aws_security_group.node_firewall.id
  cidr_ipv4         = aws_default_vpc.default.cidr_block
  ip_protocol       = "tcp"
  from_port         = 10250
  to_port           = 10250
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.node_firewall.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "internet" {
  security_group_id = aws_security_group.node_firewall.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = -1
}
