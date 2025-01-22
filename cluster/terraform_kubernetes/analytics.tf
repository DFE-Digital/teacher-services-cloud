resource "kubernetes_config_map" "ama_logs" {
  metadata {
    name      = "container-azm-ms-agentconfig"
    namespace = "kube-system"
  }

  data = {
    config-version               = "ver1"
    log-data-collection-settings = <<-EOT
    # Log data collection settings

    [log_collection_settings]
        [log_collection_settings.env_var]
          # In the absense of this configmap, default value for enabled is true
          enabled = false
        [log_collection_settings.filter_using_annotations]
          # if enabled will exclude logs from pods with annotations fluentbit.io/exclude: "true".
          # Read more: https://docs.fluentbit.io/manual/pipeline/filters/kubernetes#kubernetes-annotations
          enabled = true
    EOT
    schema-version               = "v1"
  }

}

resource "kubernetes_config_map" "ama_logs_clone" {
  count    = var.clone_cluster ? 1 : 0
  provider = kubernetes.clone
  metadata {
    name      = "container-azm-ms-agentconfig"
    namespace = "kube-system"
  }

  data = {
    config-version               = "ver1"
    log-data-collection-settings = <<-EOT
    # Log data collection settings

    [log_collection_settings]
        [log_collection_settings.env_var]
          # In the absense of this configmap, default value for enabled is true
          enabled = false
        [log_collection_settings.filter_using_annotations]
          # if enabled will exclude logs from pods with annotations fluentbit.io/exclude: "true".
          # Read more: https://docs.fluentbit.io/manual/pipeline/filters/kubernetes#kubernetes-annotations
          enabled = true
    EOT
    schema-version               = "v1"
  }

}
