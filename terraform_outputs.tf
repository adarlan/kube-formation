output "inventory" {
  value = {
    for key in keys(var.instances) : key => {
      instance_id = aws_instance.this[key].id
      public_ip   = aws_instance.this[key].public_ip
      node_role   = var.instances[key].node_role
    }
  }
}

output "worker_public_ips" {
  value = [for key, value in var.instances : aws_instance.this[key].public_ip if value.node_role == "worker"]
}
