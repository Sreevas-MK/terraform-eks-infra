resource "kubernetes_ingress_v1" "grafana_ingress" {
  depends_on = [
    kubernetes_namespace_v1.monitoring,
    helm_release.monitoring_stack,
    module.eks_blueprints_addons
  ]

  metadata {
    name      = "grafana-ingress"
    namespace = "monitoring"
    annotations = {
      "kubernetes.io/ingress.class"      = "alb"
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      # MUST match your Flask and ArgoCD group name
      "alb.ingress.kubernetes.io/group.name"       = var.alb_group_name
      "alb.ingress.kubernetes.io/certificate-arn"  = var.certificate_arn
      "alb.ingress.kubernetes.io/listen-ports"     = "[{\"HTTP\": 80}, {\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"     = "443"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/api/health"
    }
  }

  spec {
    rule {
      host = "grafana.sreevasmk.in"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "monitoring-stack-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
