provider "azurerm" { features {} }

variable "location" { type = string default = "eastus" }
variable "admin_username" { type = string default = "azureuser" }
variable "ssh_public_key" { type = string default = "~/.ssh/id_rsa.pub" }

resource "azurerm_resource_group" "rg" {
  name     = "rg-jenkins"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-jenkins"
  address_space       = ["10.10.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "default"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-jenkins"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Jenkins"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "HTTPS"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "pip" {
  name                = "pip-jenkins"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic" {
  name                = "nic-jenkins"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip.id
  }
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-jenkins"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = "Standard_B2ms"
  admin_username      = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic.id]
  admin_ssh_key { username = var.admin_username public_key = file(var.ssh_public_key) }
  os_disk { name = "osdisk-jenkins" caching = "ReadWrite" storage_account_type = "Standard_LRS" }
  source_image_reference {
    publisher = "almalinux"
    offer     = "almalinux"
    sku       = "9-gen2"
    version   = "latest"
  }
  custom_data = filebase64("${path.module}/../cloud-init/jenkins-almalinux.sh")
}

resource "azurerm_network_interface_security_group_association" "assoc" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
