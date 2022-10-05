resource "kubernetes_namespace" "default_list" {
  for_each = toset(var.namespaces)
  metadata {
    name = each.key
  }
}
