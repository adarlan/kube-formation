resource "aws_instance" "this" {
  for_each = var.instances

  instance_type = "t4g.small"

  ami      = data.aws_ami.this.id
  key_name = aws_key_pair.this.key_name

  vpc_security_group_ids = [
    aws_security_group.this["cluster"].id,
    aws_security_group.this[each.value.node_role].id,
  ]

  user_data = <<-EOF
    #cloud-config
    hostname: ${each.key}
  EOF

  tags = {
    Name = each.key
  }
}

data "aws_ami" "this" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-arm64-server-*"]
  }
}
