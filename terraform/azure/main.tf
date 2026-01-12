provider "azurerm" { features {} }

variable "location" { type = string; default = "southeastasia" }
variable "admin_username" { type = string; default = "azureuser" }
variable "ssh_public_key" { type = string; default = "~/.ssh/id_rsa.pub" }
variable "vm_size" { type = string; default = "Standard_B2ms" }

resource "azurerm_resource_group" "rg" {
  name     = "rg-jenkins"
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-jenkins"
  address_space       = ["10.10.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnets
resource "azurerm_subnet" "vm" {
  name                 = "subnet-vm"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.10.1.0/24"]
}

# Network Security Groups
resource "azurerm_network_security_group" "vm" {
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
    name                       = "HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
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

  security_rule {
    name                       = "Jenkins"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Public IPs
resource "azurerm_public_ip" "vm" {
  name                = "pip-jenkins"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface
resource "azurerm_network_interface" "vm" {
  name                = "nic-jenkins"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

# Virtual Machine
resource "azurerm_linux_virtual_machine" "jenkins" {
  name                = "vm-jenkins"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  size                = var.vm_size
  admin_username      = var.admin_username
  network_interface_ids = [azurerm_network_interface.vm.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key)
  }

  os_disk {
    name                 = "osdisk-jenkins"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "almalinux"
    offer     = "almalinux"
    sku       = "9-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/../cloud-init/jenkins-almalinux.sh", {}))
}

# Outputs
output "jenkins_public_ip" {
  description = "Public IP of Jenkins VM"
  value       = azurerm_public_ip.vm.ip_address
}

output "jenkins_http_url" {
  description = "HTTP URL to Jenkins (via Nginx reverse proxy)"
  value       = "http://${azurerm_public_ip.vm.ip_address}"
}

output "jenkins_https_url" {
  description = "HTTPS URL to Jenkins (configure TLS in Nginx)"
  value       = "https://${azurerm_public_ip.vm.ip_address}"
}

output "jenkins_direct_url" {
  description = "Direct access URL (bypass Nginx)"
  value       = "http://${azurerm_public_ip.vm.ip_address}:8080"
}

output "ssh_command" {
  description = "SSH command to connect to Jenkins VM"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.vm.ip_address}"
}

output "next_steps" {
  description = "Next steps after provisioning"
  value = <<-EOT
    1. Wait 3-5 minutes for Jenkins and Nginx to install
    2. SSH: ssh ${var.admin_username}@${azurerm_public_ip.vm.ip_address}
    3. Get admin password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword
    4. Access Jenkins via Nginx: http://${azurerm_public_ip.vm.ip_address}
    5. Direct Jenkins access: http://${azurerm_public_ip.vm.ip_address}:8080
    6. For HTTPS: Configure TLS certificate in /etc/nginx/conf.d/jenkins.conf
  EOT
}
