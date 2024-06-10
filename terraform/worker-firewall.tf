resource "aws_security_group" "worker_firewall" {
  name        = "worker_firewall"
  description = "Firewall rules for worker nodes"
  vpc_id      = aws_default_vpc.default.id

  # tags = {
  #   Name = "worker_firewall"
  # }
}

resource "aws_vpc_security_group_ingress_rule" "services" {
  security_group_id = aws_security_group.worker_firewall.id
  cidr_ipv4         = aws_default_vpc.default.cidr_block
  ip_protocol       = "tcp"
  from_port         = 30000
  to_port           = 32767
}
