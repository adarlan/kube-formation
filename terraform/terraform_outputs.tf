output "instance_ids" {
  value = {
    for key in keys(var.instances) : key => aws_instance.this[key].id
  }
}

output "public_ips" {
  value = {
    for key in keys(var.instances) : key => aws_instance.this[key].public_ip
  }
}

output "control_plane_public_ips" {
  value = [
    for key, value in var.instances :
    aws_instance.this[key].public_ip
    if value.node_role == "control-plane"
  ]
}

output "worker_public_ips" {
  value = [
    for key, value in var.instances :
    aws_instance.this[key].public_ip
    if value.node_role == "worker"
  ]
}

output "private_key" {
  value     = tls_private_key.this.private_key_openssh
  sensitive = true
}
