output "welcome_app_url" {
  value = length(var.welcome_app_hostnames) > 0 ? "https://${var.welcome_app_hostnames[0]}/" : ""
}
