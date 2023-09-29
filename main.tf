# We strongly recommend using the required_providers block to set the
# Azure Provider source and version being used
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  skip_provider_registration = true # This is only required when the User, Service Principal, or Identity running Terraform lacks the permissions to register Azure Resource Providers.
  features {}
}

resource "azurerm_resource_group" "terraform-rg" {
  name     = "terraform-resources"
  location = "West Europe"
  tags = {
    environment = "Sandbox"
    owner       = "Dan"
  }
}

resource "azurerm_virtual_network" "terraform-virtual-network" {
  name                = "terraform-virtual-network"
  resource_group_name = azurerm_resource_group.terraform-rg.name
  location            = azurerm_resource_group.terraform-rg.location
  address_space       = ["10.123.0.0/16"]
  tags = {
    environment = "Sandbox"
    owner       = "Dan"
  }
}

resource "azurerm_subnet" "terraform-virtual-network-subnet" {
  name                 = "terraform-virtual-network-subnet-1"
  resource_group_name  = azurerm_resource_group.terraform-rg.name
  virtual_network_name = azurerm_virtual_network.terraform-virtual-network.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "terraform-virtual-network-nsg" {
  name                = "terraform-virtual-network-nsg"
  location            = azurerm_resource_group.terraform-rg.location
  resource_group_name = azurerm_resource_group.terraform-rg.name
  tags = {
    environment = "Sandbox"
    owner       = "Dan"
  }
}

resource "azurerm_network_security_rule" "terraform-virtual-network-nsg-rule" {
  name                        = "terraform-virtual-network-nsg-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "92.180.8.159"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.terraform-rg.name
  network_security_group_name = azurerm_network_security_group.terraform-virtual-network-nsg.name
}

resource "azurerm_subnet_network_security_group_association" "example" {
  subnet_id                 = azurerm_subnet.terraform-virtual-network-subnet.id
  network_security_group_id = azurerm_network_security_group.terraform-virtual-network-nsg.id
}

resource "azurerm_public_ip" "terraform-public-ip1" {
  name                = "terraform-public-ip1"
  resource_group_name = azurerm_resource_group.terraform-rg.name
  location            = azurerm_resource_group.terraform-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Sandbox"
    owner       = "Dan"
  }
}

resource "azurerm_network_interface" "terraform-nic1" {
  name                = "terraform-nic1"
  location            = azurerm_resource_group.terraform-rg.location
  resource_group_name = azurerm_resource_group.terraform-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.terraform-virtual-network-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.terraform-public-ip1.id
  }
  tags = {
    environment = "Sandbox"
    owner       = "Dan"
  }
}

resource "azurerm_linux_virtual_machine" "terraform-vm1" {
  name                  = "terraform-linux-vm1"
  resource_group_name   = azurerm_resource_group.terraform-rg.name
  location              = azurerm_resource_group.terraform-rg.location
  size                  = "Standard_DS1_v2"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.terraform-nic1.id]

  custom_data = filebase64("customdata.tpl")

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/terraform-lab-key.pub")
  }

  os_disk {
    name                 = "terraform-os-disk1"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  tags = {
    environment = "Sandbox"
    owner       = "Dan"
  }

  provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "azureuser",
      IdentityFile = "~/.ssh/terraform-lab-key"
    })
    interpreter = var.host_os == "windows" ? ["Powershell", "-Command"] : ["bash", "-c"]
  }
}

data "azurerm_public_ip" "terraform-ip-data" {
  name                = azurerm_public_ip.terraform-public-ip1.name
  resource_group_name = azurerm_resource_group.terraform-rg.name
}

output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.terraform-vm1.name}: ${data.azurerm_public_ip.terraform-ip-data.ip_address}"
}