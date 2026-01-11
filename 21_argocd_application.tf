resource "kubernetes_namespace_v1" "app_ns" {
  depends_on = [
    helm_release.argocd,
    module.valkey_cache,
    module.db
  ]
  metadata {
    name = var.app_namespace
    labels = {
      "pod-security.kubernetes.io/enforce"         = "baseline"
      "pod-security.kubernetes.io/enforce-version" = "latest"
      "pod-security.kubernetes.io/warn"            = "restricted"
      "pod-security.kubernetes.io/warn-version"    = "latest"
    }
  }
}


resource "kubectl_manifest" "employees_app" {
  yaml_body = <<YAML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${var.app_name}
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${var.app_repo_url}
    targetRevision: HEAD
    path: ${var.app_repo_path}
    helm:
      parameters:
        - name: "global.host"
          value: "${var.app_host}"
        - name: "global.namespace"
          value: "${var.app_namespace}"
        - name: "global.certificate_arn"
          value: "${var.certificate_arn}"
        - name: "global.vpc_cidr"
          value: "${module.vpc.vpc_cidr_block}"
        - name: "flask.name"
          value: "${var.app_name}"
        - name: "global.alb_group_name"
          value: "${var.alb_group_name}"
        - name: "flask.env.DB_HOST"
          value: "${module.db.db_instance_address}"
        - name: "flask.env.REDIS_HOST"
          value: "${split(":", module.valkey_cache.replication_group_configuration_endpoint_address)[0]}"
        - name: "flask.env.REDIS_SSL"
          value: "true"
        - name: "flask.secrets.remoteRef.key"
          value: "${module.db.db_instance_master_user_secret_arn}"
        - name: "aws.region"
          value: "${var.aws_region}"
  destination:
    server: https://kubernetes.default.svc
    namespace: ${var.app_namespace}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=false
YAML

  depends_on = [
    kubernetes_namespace_v1.app_ns,
    helm_release.argocd,
    module.valkey_cache,
    module.db
  ]
  wait = false
}
