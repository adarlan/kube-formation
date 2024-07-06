resource "aws_key_pair" "ssh_key" {
  key_name   = "cluster_nodes_key"
  public_key = file(var.ssh_public_key_file_path)
}
