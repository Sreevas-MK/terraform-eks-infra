resource "aws_s3_bucket" "terraform_state" {
  bucket        = var.s3_bucket_name
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-terraform-state"
    Project     = var.project_name
    Environment = var.project_environment
  }
}
