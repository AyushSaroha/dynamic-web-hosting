resource "aws_key_pair" "dynamic_key" {
  key_name   = "dynamic-site-key"
  public_key = file("${path.module}/keys/dynamic-site-key.pub")

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}
