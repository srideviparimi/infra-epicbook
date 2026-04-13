resource "azurerm_resource_group" "rg" {
    name        = var.resource_group_name
    location    = var.location
}

# Vnet and subnets
resource "azurerm_virtual_network" "vnet" {
    name                = "epicbook-vnet"
    address_space       = ["10.0.0.0/16"]
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
}
resource "azurerm_subnet" "web-subnet"{
    name                 = "web-subnet"
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_subnet" "app-subnet" {
    name                 = "app-subnet"
    resource_group_name  = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes     = ["10.0.2.0/24"]
}

# public IP
resource "azurerm_public_ip" "web-pip" {
    name                = "web-pip"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    allocation_method   = "Static"
    sku                 = "Standard"
}

resource "azurerm_public_ip" "app-pip" {
    name                = "app-pip"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    allocation_method   = "Static"
    sku                 = "Standard"
}

#NSG web
resource "azurerm_network_security_group" "web-nsg" {
    name                = "web-nsg"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
   security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "116.240.32.146"
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
}
#NSG app
resource "azurerm_network_security_group" "app-nsg" {
    name                = "app-nsg"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
   security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "116.240.32.146/32"
    destination_address_prefix = "*"
    }
   security_rule {
    name                       = "APPPORT"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = azurerm_subnet.web-subnet.address_prefixes[0]
    destination_address_prefix = "*"
   }
}

#NIC- web 
resource "azurerm_network_interface" "web-nic" {
  name                = "web-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.web-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.web-pip.id 
  }
}

#NIC app
resource "azurerm_network_interface" "app-nic" {
    name                = "app-nic"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    ip_configuration {
        name                          = "internal"
        subnet_id                     = azurerm_subnet.app-subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.app-pip.id
    }
}

#NIC and NSG associations
resource "azurerm_network_interface_security_group_association" "web" {
  network_interface_id      = azurerm_network_interface.web-nic.id
  network_security_group_id = azurerm_network_security_group.web-nsg.id
}
resource "azurerm_network_interface_security_group_association" "app" {
  network_interface_id      = azurerm_network_interface.app-nic.id
  network_security_group_id = azurerm_network_security_group.app-nsg.id
}

#Azure SQL database for flexible server
resource "azurerm_mysql_flexible_server" "mysql" {
  name                   = "epicbook-mysql1203"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location

  administrator_login    = var.mysql_username
  administrator_password = var.mysql_password

  sku_name               = "B_Standard_B2s"
  version                = "8.0.21"

  storage {
    size_gb = 20
  }
  backup_retention_days = 7
}

resource "azurerm_mysql_flexible_database" "db" {
  name                = "epicbook"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  charset             = "utf8"
  collation          = "utf8_unicode_ci"
}
resource "azurerm_mysql_flexible_server_firewall_rule" "allow_backend" {
  name                = "allow-backend"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.mysql.name

  start_ip_address = "10.0.2.0"
  end_ip_address   = "10.0.2.255"
}

#VMS web and app
module "vm" {
  for_each            = toset(var.vm_roles)
  source              =  "./modules/vm"
  vm_name             = each.key
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  vm_size             = "Standard_D2s_v3"
  admin_username      = var.admin_username
  ssh_public_key      = file("/home/parimi_sridevi/.ssh/id_ed25519.pub")
  nic_id              = each.key == "web" ? azurerm_network_interface.web-nic.id :  azurerm_network_interface.app-nic.id
}