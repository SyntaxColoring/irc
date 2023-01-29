output "public_ipv4" {
  value = aws_eip.main.public_ip
}

output "public_ipv6" {
  value = "todo"
}
