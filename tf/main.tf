locals {
  architecture  = "arm64"
  instance_type = "t4g.nano"
  ami_owner     = "099720109477" # Canonical
  ami_name      = "ubuntu-minimal/images/hvm-ssd/ubuntu-jammy-22.04-arm64-minimal-20230213"
}


data "aws_ami" "main" {
  owners = [local.ami_owner]

  filter {
    name   = "name"
    values = [local.ami_name]
  }

  filter {
    name   = "architecture"
    values = [local.architecture]
  }
}


resource "aws_vpc" "main" {
  # Pick an arbitrary block of internal IPv4 addresses.
  cidr_block = "192.168.0.0/16"

  # Get AWS to assign us an arbitrary block of public IPv6 addresses.
  assign_generated_ipv6_cidr_block = true
}


# Put a single monolihic subnet in the VPC.
resource "aws_subnet" "main" {
  vpc_id = aws_vpc.main.id

  # Assign all of the VPC's IPv4 addresses to this one subnet.
  # This is arbitrary since there will only be one instance in the subnet, anyway.
  cidr_block = aws_vpc.main.cidr_block

  # AWS requires subnet IPv6 addresses to be assigned in /64 blocks.
  # Get one such block from /56 block that AWS will have assigned to the VPC.
  ipv6_cidr_block = cidrsubnet(
    aws_vpc.main.ipv6_cidr_block,
    64 - 56,
    0
  )
}


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}


resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = local.any_ipv4
    gateway_id = aws_internet_gateway.main.id
  }

  route {
    ipv6_cidr_block = local.any_ipv6
    gateway_id      = aws_internet_gateway.main.id
  }
}


resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}


resource "aws_instance" "main" {
  ami           = data.aws_ami.main.id
  instance_type = local.instance_type

  root_block_device {
    volume_type = "gp3"
  }

  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.main.id]

  ipv6_address_count = 1
}


resource "aws_security_group" "main" {
  vpc_id = aws_vpc.main.id

  ingress {
    protocol    = "icmp"
    from_port   = -1 # All ICMP types.
    to_port     = -1 # All ICMP codes.
    cidr_blocks = [local.any_ipv4]
  }
  ingress {
    protocol         = "icmpv6"
    from_port        = -1 # All ICMPv6 types.
    to_port          = -1 # All ICMPv6 codes.
    ipv6_cidr_blocks = [local.any_ipv6]
  }
  ingress {
    # SSH.
    protocol         = "tcp"
    from_port        = 22
    to_port          = 22
    cidr_blocks      = [local.any_ipv4]
    ipv6_cidr_blocks = [local.any_ipv6]
  }
  ingress {
    # HTTPS.
    protocol         = "tcp"
    from_port        = 443
    to_port          = 443
    cidr_blocks      = [local.any_ipv4]
    ipv6_cidr_blocks = [local.any_ipv6]
  }
  ingress {
    # HTTP.
    # Caddy needs this open for automatic certificate renewal.
    protocol         = "tcp"
    from_port        = 80
    to_port          = 80
    cidr_blocks      = [local.any_ipv4]
    ipv6_cidr_blocks = [local.any_ipv6]
  }
  egress {
    # Allow all outgoing traffic:
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [local.any_ipv4]
    ipv6_cidr_blocks = [local.any_ipv6]
  }
}


locals {
  any_ipv4 = "0.0.0.0/0"
  any_ipv6 = "::/0"
}


resource "aws_eip" "main" {
  instance   = aws_instance.main.id
  depends_on = [aws_internet_gateway.main]
}
