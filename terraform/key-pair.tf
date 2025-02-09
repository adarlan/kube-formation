resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "ssh_key" {
  key_name   = "cluster_nodes_key"
  public_key = tls_private_key.ssh_key.public_key_openssh
}

# TODO Use this if ED25519 is not compatible (ED25519 is more secure)
# resource "tls_private_key" "rsa-4096-example" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }
