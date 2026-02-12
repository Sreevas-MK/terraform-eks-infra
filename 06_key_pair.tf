variable "ssh_public_key" {
  type = string
}

resource "aws_key_pair" "ssh_auth_key" {
  key_name   = "eks-key"
  public_key = var.ssh_public_key
}

