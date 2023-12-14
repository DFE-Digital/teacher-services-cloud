resource "kubernetes_manifest" "configmap_monitoring_grafana_datasources" {
  manifest = {
    "apiVersion" = "v1"
    "data" = {
      "prometheus.yaml" = <<-EOT
      {
          "apiVersion": 1,
          "datasources": [
              {
                 "access":"proxy",
                  "editable": true,
                  "name": "prometheus",
                  "orgId": 1,
                  "type": "prometheus",
                  "url": "http://prometheus-service.monitoring.svc:8080",
                  "version": 1
              }
          ]
      }
      EOT
    }
    "kind" = "ConfigMap"
    "metadata" = {
      "name" = "grafana-datasources"
      "namespace" = "monitoring"
    }
  }
}

resource "kubernetes_manifest" "deployment_monitoring_grafana" {
  manifest = {
    "apiVersion" = "apps/v1"
    "kind" = "Deployment"
    "metadata" = {
      "name" = "grafana"
      "namespace" = "monitoring"
    }
    "spec" = {
      "replicas" = 1
      "selector" = {
        "matchLabels" = {
          "app" = "grafana"
        }
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "app" = "grafana"
          }
          "name" = "grafana"
        }
        "spec" = {
          "containers" = [
            {
              "image" = "grafana/grafana:latest"
              "name" = "grafana"
              "ports" = [
                {
                  "containerPort" = 3000
                  "name" = "grafana"
                },
              ]
              "resources" = {
                "limits" = {
                  "cpu" = "1"
                  "memory" = "1Gi"
                }
                "requests" = {
                  "cpu" = "500m"
                  "memory" = "500M"
                }
              }
              "volumeMounts" = [
                {
                  "mountPath" = "/var/lib/grafana"
                  "name" = "grafana-storage"
                },
                {
                  "mountPath" = "/etc/grafana/provisioning/datasources"
                  "name" = "grafana-datasources"
#                  "readOnly" = null
                },
              ]
            },
          ]
          "volumes" = [
            {
              "emptyDir" = {}
              "name" = "grafana-storage"
            },
            {
              "configMap" = {
                "defaultMode" = 420
                "name" = "grafana-datasources"
              }
              "name" = "grafana-datasources"
            },
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "service_monitoring_grafana" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "Service"
    "metadata" = {
      "annotations" = {
        "prometheus.io/port" = "3000"
        "prometheus.io/scrape" = "true"
      }
      "name" = "grafana"
      "namespace" = "monitoring"
    }
    "spec" = {
      "ports" = [
        {
          "nodePort" = 32000
          "port" = 3000
          "targetPort" = 3000
        },
      ]
      "selector" = {
        "app" = "grafana"
      }
      "type" = "NodePort"
    }
  }
}
