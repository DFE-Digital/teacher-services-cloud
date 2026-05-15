resource "kubernetes_namespace" "default_list" {
  for_each = toset(var.namespaces)
  metadata {
    name = each.key
    labels = {
      traefik-watch = contains(var.traefik-watch, each.key) ? true : false
    }
  }
}

resource "kubernetes_namespace" "default_list_clone" {
  for_each = var.clone_cluster ? toset(var.namespaces) : []
  provider = kubernetes.clone

  metadata {
    name = each.key
  }
}
