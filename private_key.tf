resource "tls_private_key" "this" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "private_key" {
  filename        = "private_key"
  content         = tls_private_key.this.private_key_openssh
  file_permission = "600"
}
