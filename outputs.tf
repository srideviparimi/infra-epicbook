output "app_public_ip" {
  value = azurerm_public_ip.pip.ip_address
  description = "Frontend VM Public IP"
}
output "backend_private_ip" {
  value = azurerm_network_interface.app-nic.private_ip_address
  description = "Backend VM Private IP"
}
output "mysql_fqdn" {
  value = azurerm_mysql_flexible_server.mysql.fqdn
  description = "MySQL Flexible Server hostname"
}