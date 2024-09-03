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
        automount_service_account_token = false
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
          image = "nginxinc/nginx-unprivileged:1.26.1"

          security_context {
            run_as_user  = 1000
            run_as_group = 3000
            capabilities {
              drop = ["ALL"]
            }
            allow_privilege_escalation = false
            privileged                 = false
            run_as_non_root            = true
            read_only_root_filesystem  = true
            seccomp_profile {
              type = "RuntimeDefault"
            }
          }

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

          # Mount the updated NGINX configuration from the ConfigMap
          volume_mount {
            name       = "nginx-config-volume"
            mount_path = "/etc/nginx/conf.d/default.conf"
            sub_path   = "default.conf"
          }

          # Mount a writable volume to /tmp
          volume_mount {
            name       = "nginx-tmp"
            mount_path = "/tmp"
          }
          volume_mount {
            name       = "nginx-cache"
            mount_path = "/var/cache/nginx"
          }
        }

        volume {
          name = "nginx-config-volume"
          config_map {
            name = kubernetes_config_map.welcome_app_nginx_config.metadata[0].name
          }
        }

        volume {
          name = "nginx-tmp"
          empty_dir {}
        }

        volume {
          name = "nginx-cache"
          empty_dir {}
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
      target_port = 8080
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

resource "kubernetes_config_map" "welcome_app_nginx_config" {
  metadata {
    name      = "nginx-config"
    namespace = kubernetes_namespace.default_list[local.welcome_app_namespace].metadata[0].name
  }

  data = {
    "default.conf" = <<EOT
server {
    listen       8080;
    server_name  localhost;

    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
    }

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/share/nginx/html;
    }
}
EOT
  }
}
