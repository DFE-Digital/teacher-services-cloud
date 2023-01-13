data "kubernetes_service" "default" {
  metadata {
    name = "ingress-nginx-controller"
  }

  depends_on = [
    helm_release.ingress-nginx
  ]

}

resource "azurerm_dns_a_record" "cluster_a_record" {

  count = var.cluster_dns_zone != null ? 1 : 0

  name                = "*.${var.environment}"
  zone_name           = var.cluster_dns_zone
  resource_group_name = var.cluster_dns_resource_group_name
  ttl                 = 300
  records             = toset([data.kubernetes_service.default.status.0.load_balancer.0.ingress[0].ip])
}
