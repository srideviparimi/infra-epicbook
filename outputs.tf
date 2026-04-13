output "web_public_ip" {
  value = azurerm_public_ip.web-pip.ip_address
  description = "Frontend VM Public IP"
}
output "app_public_ip" {
  value = azurerm_public_ip.app-pip.ip_address
  description = "Backend VM Public IP"
}
output "mysql_fqdn" {
  value = azurerm_mysql_flexible_server.mysql.fqdn
  description = "MySQL Flexible Server hostname"
}