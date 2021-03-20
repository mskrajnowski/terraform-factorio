output "ip" {
  value = aws_eip.router.public_ip
}

output "id" {
  value = aws_eip.router.id
}
