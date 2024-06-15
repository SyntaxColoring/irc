output "public_ipv6" {
  value = aws_instance.main.ipv6_addresses[0]
}

output "instance_id" {
  value = aws_instance.main.id
}
