output "nodes" {
  value = {
    for node_key, node_value in local.nodes : node_key => {
      role        = node_value.role
      public_ip   = aws_eip.this[node_key].public_ip
      instance_id = aws_instance.this[node_key].id
    }
  }
}

output "private_key" {
  value     = tls_private_key.this.private_key_openssh
  sensitive = true
}
