locals {
  architecture           = "arm64"
  instance_type          = "t4g.nano"
  thelounge_deb_download = "https://github.com/thelounge/thelounge/releases/download/v4.3.1/thelounge_4.3.1-2_all.deb"
}


data "aws_ami" "main" {
  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu-minimal/images/hvm-ssd/ubuntu-jammy-22.04-arm64-minimal-*"]
  }

  filter {
    name   = "architecture"
    values = [local.architecture]
  }

  most_recent = true
}


resource "aws_instance" "main" {
  ami           = data.aws_ami.main.id
  instance_type = local.instance_type

  security_groups = [aws_security_group.main.name]

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
              "${path.module}/Caddyfile.tftpl",
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
            content = file("${path.module}/thelounge.service")
          }
        ]

        apt = {
          # TODO: Do we need this?
          preserve_sources_list = true

          sources = {
            # Adapted from https://caddyserver.com/docs/install#debian-ubuntu-raspbian.
            caddy = {
              source = "deb [signed-by=$KEY_FILE] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main"
              key    = file("${path.module}/caddy_public_key.gpg")
            }

            # Adapted from https://docs.docker.com/engine/install/ubuntu/.
            docker = {
              source = "deb [signed-by=$KEY_FILE] https://download.docker.com/linux/ubuntu jammy stable"
              key    = file("${path.module}/docker_public_key.gpg")
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
  instance = aws_instance.main.id
}
