# Create IAM Role for External Secrets Operator (IRSA)
module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${var.project_name}-external-secrets-irsa"

  depends_on = [module.eks]

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["external-secrets:external-secrets-sa"]
    }
  }

  role_policy_arns = {
    policy = aws_iam_policy.external_secrets_policy.arn
  }
}

resource "aws_iam_policy" "external_secrets_policy" {
  name        = "${var.project_name}-external-secrets-policy"
  path        = "/"
  description = "Allow ESO to read RDS secrets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Effect   = "Allow"
        Resource = [module.db.db_instance_master_user_secret_arn]
      }
    ]
  })
}
