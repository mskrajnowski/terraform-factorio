output "nat_port" {
  value = var.nat_port
}

output "nat_rcon_port" {
  value = var.nat_rcon_port
}

output "rcon_password" {
  value     = local.rcon_password
  sensitive = true
}
