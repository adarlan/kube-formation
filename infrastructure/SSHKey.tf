resource "aws_key_pair" "this" {
  key_name   = "kube-formation"
  public_key = file("../ssh/id_ed25519.pub")
}
