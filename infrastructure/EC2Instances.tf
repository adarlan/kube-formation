locals {
  control_plane_count = 1
  worker_count        = 1

  nodes = merge(
    {
      for i in range(local.control_plane_count) :
      "controlplane${i + 1}" => {
        role               = "control-plane"
        security_group_ids = local.control_plane_security_group_ids
      }
    },
    {
      for i in range(local.worker_count) :
      "worker${i + 1}" => {
        role               = "worker"
        security_group_ids = local.worker_security_group_ids
      }
    }
  )
}

resource "aws_instance" "this" {
  for_each = local.nodes

  ami                    = data.aws_ami.this.id
  instance_type          = "t4g.small"
  vpc_security_group_ids = each.value.security_group_ids
  key_name               = aws_key_pair.this.key_name

  # Shut down 3 hours after every boot, including after stop/start cycles.
  user_data = <<-EOF
    #cloud-config
    hostname: ${each.key}
    bootcmd:
      - shutdown -h +180
  EOF

  tags = {
    Name = each.key
  }
}
