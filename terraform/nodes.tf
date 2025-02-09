resource "aws_instance" "nodes" {
  for_each = {

    "control-plane" = {
      security_group_ids = [
        aws_security_group.node_firewall.id,
        aws_security_group.control_plane_firewall.id
      ]
    }

    "worker-1" = {
      security_group_ids = [
        aws_security_group.node_firewall.id,
        aws_security_group.worker_firewall.id
      ]
    }

    "worker-2" = {
      security_group_ids = [
        aws_security_group.node_firewall.id,
        aws_security_group.worker_firewall.id
      ]
    }
  }

  ami           = data.aws_ami.node_image.id
  instance_type = "t4g.small"

  tags = {
    Name = each.key
  }

  vpc_security_group_ids = each.value.security_group_ids

  user_data = file("nodes-user-data.sh")

  key_name = aws_key_pair.ssh_key.key_name
}
