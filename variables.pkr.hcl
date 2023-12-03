variable "client_id" {
  type      = string
  default   = env("AZURE_CLIENT_ID")
  sensitive = true
}

variable "client_secret" {
  type      = string
  default   = env("AZURE_CLIENT_SECRET")
  sensitive = true
}

variable "tenant_id" {
  type      = string
  default   = env("AZURE_TENANT_ID")
  sensitive = true
}

variable "subscription_id" {
  type      = string
  default   = env("AZURE_SUBSCRIPTION_ID")
  sensitive = true
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

