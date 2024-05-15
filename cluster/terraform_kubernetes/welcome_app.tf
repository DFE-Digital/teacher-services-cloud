resource "kubernetes_deployment" "welcome_app" {
  metadata {
    name      = local.welcome_app_name
    namespace = kubernetes_namespace.default_list[local.welcome_app_namespace].metadata[0].name
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = local.welcome_app_name
      }
    }
    template {
      metadata {
        labels = {
          app = local.welcome_app_name
        }
        annotations = {
          "logit.io/send"        = "true"
          "fluentbit.io/exclude" = "true"
        }
      }
      spec {
        node_selector = {
          "teacherservices.cloud/node_pool" = "applications"
          "kubernetes.io/os"                = "linux"
        }
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "DoNotSchedule"
          label_selector {
            match_labels = {
              app = local.welcome_app_name
            }
          }
        }
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "kubernetes.io/hostname"
          when_unsatisfiable = "ScheduleAnyway"
          label_selector {
            match_labels = {
              app = local.welcome_app_name
            }
          }
        }

        container {
          name  = local.welcome_app_name
          image = "nginx"

          resources {
            requests = {
              cpu    = "100m"
              memory = "64M"
            }
            limits = {
              cpu    = "100m"
              memory = "64M"
            }
          }
          port {
            container_port = 80
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "welcome_app" {
  metadata {
    name      = local.welcome_app_name
    namespace = kubernetes_namespace.default_list[local.welcome_app_namespace].metadata[0].name
  }
  spec {
    type = "ClusterIP"
    port {
      port        = 80
      target_port = 80
    }
    selector = {
      app = local.welcome_app_name
    }
  }
}

resource "kubernetes_ingress_v1" "welcome_app" {
  for_each = toset(local.welcome_app_hostnames)

  wait_for_load_balancer = true
  metadata {
    name      = "${local.welcome_app_name}-${each.value}"
    namespace = local.welcome_app_namespace
  }
  spec {
    ingress_class_name = local.ingress_class_name
    rule {
      host = each.value
      http {
        path {
          backend {
            service {
              name = kubernetes_service.welcome_app.metadata[0].name
              port {
                number = kubernetes_service.welcome_app.spec[0].port[0].port
              }
            }
          }
        }
      }
    }
  }
}
