resource "kubernetes_manifest" "clusterrole_kube_state_metrics" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind" = "ClusterRole"
    "metadata" = {
      "labels" = {
        "app.kubernetes.io/component" = "exporter"
        "app.kubernetes.io/name" = "kube-state-metrics"
        "app.kubernetes.io/version" = "2.3.0"
      }
      "name" = "kube-state-metrics"
    }
    "rules" = [
      {
        "apiGroups" = [
          "",
        ]
        "resources" = [
          "configmaps",
          "secrets",
          "nodes",
          "pods",
          "services",
          "resourcequotas",
          "replicationcontrollers",
          "limitranges",
          "persistentvolumeclaims",
          "persistentvolumes",
          "namespaces",
          "endpoints",
        ]
        "verbs" = [
          "list",
          "watch",
        ]
      },
      {
        "apiGroups" = [
          "apps",
        ]
        "resources" = [
          "statefulsets",
          "daemonsets",
          "deployments",
          "replicasets",
        ]
        "verbs" = [
          "list",
          "watch",
        ]
      },
      {
        "apiGroups" = [
          "batch",
        ]
        "resources" = [
          "cronjobs",
          "jobs",
        ]
        "verbs" = [
          "list",
          "watch",
        ]
      },
      {
        "apiGroups" = [
          "autoscaling",
        ]
        "resources" = [
          "horizontalpodautoscalers",
        ]
        "verbs" = [
          "list",
          "watch",
        ]
      },
      {
        "apiGroups" = [
          "authentication.k8s.io",
        ]
        "resources" = [
          "tokenreviews",
        ]
        "verbs" = [
          "create",
        ]
      },
      {
        "apiGroups" = [
          "authorization.k8s.io",
        ]
        "resources" = [
          "subjectaccessreviews",
        ]
        "verbs" = [
          "create",
        ]
      },
      {
        "apiGroups" = [
          "policy",
        ]
        "resources" = [
          "poddisruptionbudgets",
        ]
        "verbs" = [
          "list",
          "watch",
        ]
      },
      {
        "apiGroups" = [
          "certificates.k8s.io",
        ]
        "resources" = [
          "certificatesigningrequests",
        ]
        "verbs" = [
          "list",
          "watch",
        ]
      },
      {
        "apiGroups" = [
          "storage.k8s.io",
        ]
        "resources" = [
          "storageclasses",
          "volumeattachments",
        ]
        "verbs" = [
          "list",
          "watch",
        ]
      },
      {
        "apiGroups" = [
          "admissionregistration.k8s.io",
        ]
        "resources" = [
          "mutatingwebhookconfigurations",
          "validatingwebhookconfigurations",
        ]
        "verbs" = [
          "list",
          "watch",
        ]
      },
      {
        "apiGroups" = [
          "networking.k8s.io",
        ]
        "resources" = [
          "networkpolicies",
          "ingresses",
        ]
        "verbs" = [
          "list",
          "watch",
        ]
      },
      {
        "apiGroups" = [
          "coordination.k8s.io",
        ]
        "resources" = [
          "leases",
        ]
        "verbs" = [
          "list",
          "watch",
        ]
      },
    ]
  }
}

resource "kubernetes_manifest" "clusterrolebinding_kube_state_metrics" {
  manifest = {
    "apiVersion" = "rbac.authorization.k8s.io/v1"
    "kind" = "ClusterRoleBinding"
    "metadata" = {
      "labels" = {
        "app.kubernetes.io/component" = "exporter"
        "app.kubernetes.io/name" = "kube-state-metrics"
        "app.kubernetes.io/version" = "2.3.0"
      }
      "name" = "kube-state-metrics"
    }
    "roleRef" = {
      "apiGroup" = "rbac.authorization.k8s.io"
      "kind" = "ClusterRole"
      "name" = "kube-state-metrics"
    }
    "subjects" = [
      {
        "kind" = "ServiceAccount"
        "name" = "kube-state-metrics"
        "namespace" = "kube-system"
      },
    ]
  }
}

resource "kubernetes_manifest" "serviceaccount_kube_system_kube_state_metrics" {
  manifest = {
    "apiVersion" = "v1"
    "automountServiceAccountToken" = false
    "kind" = "ServiceAccount"
    "metadata" = {
      "labels" = {
        "app.kubernetes.io/component" = "exporter"
        "app.kubernetes.io/name" = "kube-state-metrics"
        "app.kubernetes.io/version" = "2.3.0"
      }
      "name" = "kube-state-metrics"
      "namespace" = "kube-system"
    }
  }
}

resource "kubernetes_manifest" "deployment_kube_system_kube_state_metrics" {
  manifest = {
    "apiVersion" = "apps/v1"
    "kind" = "Deployment"
    "metadata" = {
      "labels" = {
        "app.kubernetes.io/component" = "exporter"
        "app.kubernetes.io/name" = "kube-state-metrics"
        "app.kubernetes.io/version" = "2.3.0"
      }
      "name" = "kube-state-metrics"
      "namespace" = "kube-system"
    }
    "spec" = {
      "replicas" = 1
      "selector" = {
        "matchLabels" = {
          "app.kubernetes.io/name" = "kube-state-metrics"
        }
      }
      "template" = {
        "metadata" = {
          "labels" = {
            "app.kubernetes.io/component" = "exporter"
            "app.kubernetes.io/name" = "kube-state-metrics"
            "app.kubernetes.io/version" = "2.3.0"
          }
        }
        "spec" = {
          "automountServiceAccountToken" = true
          "containers" = [
            {
              "image" = "k8s.gcr.io/kube-state-metrics/kube-state-metrics:v2.3.0"
              "livenessProbe" = {
                "httpGet" = {
                  "path" = "/healthz"
                  "port" = 8080
                }
                "initialDelaySeconds" = 5
                "timeoutSeconds" = 5
              }
              "name" = "kube-state-metrics"
              "ports" = [
                {
                  "containerPort" = 8080
                  "name" = "http-metrics"
                },
                {
                  "containerPort" = 8081
                  "name" = "telemetry"
                },
              ]
              "readinessProbe" = {
                "httpGet" = {
                  "path" = "/"
                  "port" = 8081
                }
                "initialDelaySeconds" = 5
                "timeoutSeconds" = 5
              }
              "securityContext" = {
                "allowPrivilegeEscalation" = false
                "readOnlyRootFilesystem" = true
                "runAsUser" = 65534
              }
            },
          ]
          "nodeSelector" = {
            "kubernetes.io/os" = "linux"
          }
          "serviceAccountName" = "kube-state-metrics"
        }
      }
    }
  }
}

resource "kubernetes_manifest" "service_kube_system_kube_state_metrics" {
  manifest = {
    "apiVersion" = "v1"
    "kind" = "Service"
    "metadata" = {
      "labels" = {
        "app.kubernetes.io/component" = "exporter"
        "app.kubernetes.io/name" = "kube-state-metrics"
        "app.kubernetes.io/version" = "2.3.0"
      }
      "name" = "kube-state-metrics"
      "namespace" = "kube-system"
    }
    "spec" = {
      "clusterIP" = "None"
      "ports" = [
        {
          "name" = "http-metrics"
          "port" = 8080
          "targetPort" = "http-metrics"
        },
        {
          "name" = "telemetry"
          "port" = 8081
          "targetPort" = "telemetry"
        },
      ]
      "selector" = {
        "app.kubernetes.io/name" = "kube-state-metrics"
      }
    }
  }
}
