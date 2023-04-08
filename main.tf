# Generate random string as prefix to all resources
resource "random_string" "prefix" {
  length  = 5
  special = false
  upper   = true
  lower   = false
  numeric = false
}

# Create resource group
resource "azurerm_resource_group" "rg" {
  name     = "${random_string.prefix.result}-azure-container-registry-demo"
  location = "Southeast Asia"
  tags = {
    "usage" = "azure container registry demo"
  }
}

# Create the azure container registry
resource "azurerm_container_registry" "acr" {
  name                = "${lower(random_string.prefix.result)}acr"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = azurerm_resource_group.rg.tags
}

# Get ubuntu image info
data "docker_registry_image" "ubuntu" {
  name = "ubuntu:latest"
}

# Pull ubuntu image from docker and update
resource "docker_image" "ubuntu" {
  name = data.docker_registry_image.ubuntu.name
  build {
    context    = "."
    dockerfile = "Dockerfile"
  }
}

# Push ubuntu image to azure registry
resource "null_resource" "push_ubuntu" {
  triggers = {
    always_run = file("${path.module}/Dockerfile")
  }

  provisioner "local-exec" {
    command = <<-EOT
      LOGIN_SERVER="${azurerm_container_registry.acr.login_server}"
      USER="${azurerm_container_registry.acr.admin_username}"
      PASSWD="${azurerm_container_registry.acr.admin_password}"
      IMAGE_NAME="${docker_image.ubuntu.name}"
      REGISTRY_NAME="${azurerm_container_registry.acr.name}"
      docker login $LOGIN_SERVER -u $USER -p $PASSWD
      docker tag $IMAGE_NAME $LOGIN_SERVER/$IMAGE_NAME
      docker push $LOGIN_SERVER/$IMAGE_NAME
    EOT
  }

  depends_on = [
    docker_image.ubuntu,
    azurerm_container_registry.acr
  ]
}

# Pull ubuntu image from azure registry
resource "docker_image" "ubuntu_acr" {
  name = "${azurerm_container_registry.acr.login_server}/ubuntu:latest"

  depends_on = [
    null_resource.push_ubuntu
  ]
}
