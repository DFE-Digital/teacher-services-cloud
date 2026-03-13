
  set {
    name  = "controller.config.proxy-body-size"
    value = "50m"
    type  = "string"
  }

  set {
    name  = "controller.config.proxy-buffer-size"
    value = "24k"
    type  = "string"
  }

  set {
    name  = "controller.config.keep-alive"
    value = "120"
    type  = "auto"
  }

  set {
    name  = "controller.config.client-header-timeout"
    value = "120"
    type  = "auto"
  }



  dynamic "set" {
    for_each = var.block_metrics_endpoint ? [1] : []

    content {
      name  = "controller.config.server-snippet"
      value = <<-EOT
        location /metrics {
            deny all;
        }
      EOT
      type  = "string"
    }
  }