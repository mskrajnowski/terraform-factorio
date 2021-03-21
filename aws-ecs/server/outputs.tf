output "nat_port" {
  value = var.nat_port
}

output "nat_rcon_port" {
  value = var.nat_rcon_port
}

output "address" {
  value = "${var.cluster.nat_ip}:${var.nat_port}"
}

output "rcon_address" {
  value = "${var.cluster.nat_ip}:${var.nat_rcon_port}"
}

output "rcon_password" {
  value     = local.rcon_password
  sensitive = true
}
