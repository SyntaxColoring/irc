output "public_ipv4" {
  value = aws_eip.main.public_ip
}

output "public_ipv6" {
  value = aws_instance.main.ipv6_addresses[0]
}
