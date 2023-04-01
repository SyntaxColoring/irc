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

  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.main.id]

  ipv6_address_count = 1

  key_name = aws_key_pair.main.key_name

  user_data = data.cloudinit_config.main.rendered
  # Hack: Allow refactors to user_data without having to recreate the instance.
  # But if we change something that matters, we have to remember to recreate
  # it manually.
  user_data_replace_on_change = false
}


data "cloudinit_config" "main" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content = jsonencode(
      {
        write_files = [
          {
            # Ubuntu's service files for Caddy look for a default Caddyfile here.
            # TODO: Find a way to allow modifying these without recreating
            # the whole instance. A stop-start would be okay.
            path = "/etc/caddy/Caddyfile"
            content = templatefile(
              "${path.module}/files/Caddyfile.tftpl",
              {
                host        = var.host,
                email       = var.email,
                tls_staging = var.tls_staging,
              }
            )
          },
          {
            # TODO: Find a way to set up good defaults for thelounge config,
            # like reverseProxy=true.
            path    = "/etc/systemd/system/thelounge.service"
            content = file("${path.module}/files/thelounge.service")
          }
        ]

        apt = {
          # TODO: Do we need this?
          preserve_sources_list = true

          sources = {
            # Adapted from https://caddyserver.com/docs/install#debian-ubuntu-raspbian.
            caddy = {
              source = "deb [signed-by=$KEY_FILE] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main"
              key    = file("${path.module}/files/caddy_public_key.gpg")
            }

            # Adapted from https://docs.docker.com/engine/install/ubuntu/.
            docker = {
              source = "deb [signed-by=$KEY_FILE] https://download.docker.com/linux/ubuntu jammy stable"
              key    = file("${path.module}/files/docker_public_key.gpg")
            }
          }
        }

        packages = [
          "caddy",

          # We use Docker even though The Lounge provides a plain Ubuntu package
          # because the plain Ubuntu package compiles SQLite at install time, which
          # seems to bump up against our instance's memory limits.
          "docker-ce",
          "docker-ce-cli",
          "containerd.io",
        ]

        runcmd = [
          # Start thelounge.service on this boot and configure it to automatically start on subsequent boots.
          ["systemctl", "enable", "--now", "--no-block", "thelounge"]
        ]
      }
    )
  }
}


resource "aws_key_pair" "main" {
  public_key = var.public_key
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
