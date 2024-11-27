output "url" {
  value = module.web_application.url
}

output "external_urls" {
  value = [
    local.external_url
  ]
}
