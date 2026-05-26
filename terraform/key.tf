resource "aws_key_pair" "dynamic_key" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)

  lifecycle {
    prevent_destroy = true
    ignore_changes  = all
  }
}
