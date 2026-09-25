locals {
  managed_tls_enabled  = var.enable_managed_tls
  install_cert_manager = var.install_cert_manager && (local.managed_tls_enabled || local.langfuse_self_hosted)
  letsencrypt_email    = var.letsencrypt_email != "" ? var.letsencrypt_email : "letsencrypt@${var.domain_name}"
  letsencrypt_server   = var.letsencrypt_server == "staging" ? "https://acme-staging-v02.api.letsencrypt.org/directory" : "https://acme-v02.api.letsencrypt.org/directory"
}

resource "helm_release" "cert_manager" {
  count            = local.install_cert_manager ? 1 : 0
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.17.2"
  namespace        = "cert-manager"
  create_namespace = true
  timeout          = 600

  set {
    name  = "crds.enabled"
    value = "true"
  }

  depends_on = [time_sleep.wait_for_cluster]
}

resource "time_sleep" "wait_for_cert_manager" {
  count           = local.install_cert_manager ? 1 : 0
  create_duration = "30s"

  depends_on = [helm_release.cert_manager]
}

# Helm instead of kubernetes_manifest so plan does not require cert-manager CRDs on the API.
resource "helm_release" "letsencrypt_tls" {
  count     = local.managed_tls_enabled ? 1 : 0
  name      = "letsencrypt-tls"
  chart     = "${path.module}/charts/letsencrypt-tls"
  namespace = kubernetes_namespace.sligo.metadata[0].name
  timeout   = 600

  values = [yamlencode({
    enabled              = true
    email                = local.letsencrypt_email
    server               = local.letsencrypt_server
    privateKeySecretName = "letsencrypt-account-key"
    ingressClass         = "nginx"
    issuerName           = "letsencrypt"
    app = {
      enabled    = true
      name       = "app-tls"
      secretName = "app-tls-cert"
      dnsNames   = [var.domain_name, "api.${var.domain_name}"]
    }
    langfuse = {
      enabled    = local.langfuse_self_hosted && var.langfuse_web_enabled
      name       = "langfuse-tls"
      secretName = "langfuse-tls-cert"
      dnsNames   = [local.langfuse_domain]
    }
  })]

  depends_on = [
    kubernetes_namespace.sligo,
    helm_release.nginx_ingress,
    helm_release.cert_manager,
    time_sleep.wait_for_cert_manager,
  ]
}
