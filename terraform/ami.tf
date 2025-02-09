data "aws_ami" "node_image" {
  # executable_users = ["self"]
  most_recent      = true
  # name_regex       = "^myami-\\d{3}"
  owners           = ["self"]

  filter {
    name   = "name"
    values = ["my-k8s-ami-*"]
  }
}
