resource "aws_eip" "this" {
  for_each = local.nodes

  domain = "vpc"

  tags = {
    Name = "kube-formation-${each.key}"
  }
}

resource "aws_eip_association" "this" {
  for_each = local.nodes

  instance_id   = aws_instance.this[each.key].id
  allocation_id = aws_eip.this[each.key].id
}
