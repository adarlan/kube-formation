output "control_plane_ip" {
  value = aws_instance.nodes["control-plane"].public_ip
}

output "worker_1_ip" {
  value = aws_instance.nodes["worker-1"].public_ip
}

output "worker_2_ip" {
  value = aws_instance.nodes["worker-2"].public_ip
}
