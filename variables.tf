variable "admin_username" {
    type = string
}
variable "location" {
    default = "Canada Central"
}
variable "vm_roles" {
    default = ["web", "app"]
}
variable "resource_group_name" {
    default = "rg-epicbook"
}
variable "subscription_id" {
    type = string
}

variable "mysql_username"{
    type = string
}
variable "mysql_password" {
    type = string
}