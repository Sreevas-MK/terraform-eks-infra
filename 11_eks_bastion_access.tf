resource "aws_eks_access_entry" "bastion_user" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.bastion_role.arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "bastion_admin" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_iam_role.bastion_role.arn

  access_scope {
    type = "cluster"
  }
}
