terraform {
  backend "s3" {
    bucket         = "eks-project-terraform-state-0001"
    key            = "eks/eks.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "eks-project-terraform-locks-0001"
    encrypt        = true
  }
}

