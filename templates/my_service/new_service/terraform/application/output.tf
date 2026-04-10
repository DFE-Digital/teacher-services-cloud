output "url" {
  value = module.web_application.url
}

output "external_urls" {
  value = [
    module.web_application.url
  ]
}
