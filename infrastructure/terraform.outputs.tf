output "nodes" {
  value = {
    for node_key, node_value in local.nodes : node_key => {
      role        = node_value.role
      public_ip   = aws_eip.this[node_key].public_ip
      instance_id = aws_instance.this[node_key].id
    }
  }
}

output "control_plane_nodes" {
  value = {
    for node_key, node_value in local.nodes : node_key => {
      role        = node_value.role
      public_ip   = aws_eip.this[node_key].public_ip
      instance_id = aws_instance.this[node_key].id
    } if node_value.role == "control-plane"
  }
}

output "worker_nodes" {
  value = {
    for node_key, node_value in local.nodes : node_key => {
      role        = node_value.role
      public_ip   = aws_eip.this[node_key].public_ip
      instance_id = aws_instance.this[node_key].id
    } if node_value.role == "worker"
  }
}
