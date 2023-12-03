packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "~> 1"
    }
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

build {
  name = "actividad1"

  sources = [
    "source.amazon-ebs.ubuntu",
    "source.azure-arm.ubuntu"
  ]

  provisioner "file" {
    source      = "files/nginx.conf"
    destination = "/tmp/nginx.conf"
  }

  provisioner "file" {
    source      = "files/app.js"
    destination = "/tmp/app.js"
  }

  provisioner "shell" {
    script = "files/install.sh"
  }

  provisioner "shell" {
    inline = ["sudo systemctl status nginx"]
  }

  provisioner "shell" {
    inline = ["export CLOUD_PROVIDER='AMAZON AWS'"]
    only   = ["amazon-ebs.ubuntu"]
  }

  provisioner "shell" {
    inline = ["export CLOUD_PROVIDER='Microsoft Azure'"]
    only   = ["azure-arm.ubuntu"]
  }

  post-processor "manifest" {
    output = "manifest.json"
  }
}

