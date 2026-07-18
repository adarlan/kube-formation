resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "this" {
  key_name   = "kubeadm-lab"
  public_key = tls_private_key.this.public_key_openssh
}
