resource "kubernetes_daemonset" "node-exporter" {

  metadata {
    name      = "node-exporter"
    namespace = kubernetes_namespace.default_list["monitoring"].metadata[0].name
    labels = {
      name = "node-exporter"
    }
  }

  spec {
    selector {
      match_labels = {
        name = "node-exporter"
      }
    }


    template {
      metadata {
        annotations = {
          "prometheus.io/port"   = "9100"
          "prometheus.io/scrape" = "true"
        }
        labels = {
          name = "node-exporter"
        }
      }

      spec {

        container {
          image = "${var.tsc_package_repo}:${var.node_exporter_image}-${var.node_exporter_version}"
          name  = "node-exporter"
          security_context {
            run_as_user  = 65534
            run_as_group = 65534
            capabilities {
              drop = ["ALL"]
            }
            allow_privilege_escalation = false
            privileged                 = false
            run_as_non_root            = true
            read_only_root_filesystem  = true
          }

          args = [
            "--path.sysfs=/host/sys",
            "--path.rootfs=/host/root",
            "--no-collector.diskstats",
            "--collector.filesystem.ignored-mount-points=^/(dev|proc|sys|etc|mnt|boot/efi|run|run.+|var/lib/kube.+|var/run/secrets.+)($|/)",
            "--collector.netclass.ignored-devices=^(veth.*)$"
          ]

          port {
            container_port = 9100
            protocol       = "TCP"
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "100Mi"
            }
            requests = {
              cpu    = "10m"
              memory = "100Mi"
            }
          }

          volume_mount {
            mount_path        = "/host/sys"
            name              = "sys"
            mount_propagation = "HostToContainer"
            read_only         = "true"
          }

          volume_mount {
            mount_path        = "/host/root"
            name              = "root"
            mount_propagation = "HostToContainer"
            read_only         = "true"
          }
        }

        volume {
          name = "sys"
          host_path {
            path = "/sys"
          }
        }

        volume {
          name = "root"
          host_path {
            path = "/"
          }
        }

      }
    }
  }
}
