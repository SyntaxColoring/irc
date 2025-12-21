from io import StringIO
from textwrap import dedent

from pyinfra import host
from pyinfra.operations import apt, files, server, systemd


THELOUNGE_RELEASE = "https://github.com/thelounge/thelounge-deb/releases/download/v4.4.3/thelounge_4.4.3_all.deb"


host_fqdn = host.data.get("fqdn")
if not isinstance(host_fqdn, str):
    # Caddy needs the FQDN for getting a public certificate.
    # There's probably some way to fall back to insecure http:// or a self-signed certificate
    # but I couldn't figure out the Caddy config for that, so let's just require the FQDN here.
    raise ValueError("fqdn required. Try `pyinfra --data fqdn=example.com ...`.")


def generate_caddy_config(host: str) -> str:
    return dedent(
        f"""\
        {host}
        reverse_proxy localhost:9000
        """
    )


server.hostname(hostname=host_fqdn)

# Adapted from https://caddyserver.com/docs/install#debian-ubuntu-raspbian.
files.download(
    name="Add signing key for Caddy respository",
    src="https://dl.cloudsmith.io/public/caddy/stable/gpg.key",
    dest="/etc/apt/keyrings/caddy.asc",
    mode="u=rw,g=r,o=r",
)
apt.repo(
    name="Add Caddy repository",
    src="deb [signed-by=/etc/apt/keyrings/caddy.asc] https://dl.cloudsmith.io/public/caddy/stable/deb/debian any-version main"
)
apt.packages(
    name="Install Caddy",
    packages="caddy"
)

configure_caddy = files.put(
    name="Configure Caddy",
    src=StringIO(generate_caddy_config(host_fqdn)),
    dest="/etc/caddy/Caddyfile",
    user="caddy",
    group="caddy",
    mode="660"
)
systemd.service(
    service="caddy",
    reloaded=True,
    _if=[configure_caddy.did_change]
)

apt.deb(
    name="Install The Lounge",
    src=THELOUNGE_RELEASE,
)

configure_thelounge = files.put(
    name="Configure The Lounge",
    src="files/config.js",
    dest="/etc/thelounge/config.js",
    user="thelounge",
    group="thelounge",
    mode="660"
)
systemd.service(
    service="thelounge",
    restarted=True,
    _if=[configure_thelounge.did_change]
)

files.put(
    name="Configure unattended-upgrades",
    src="files/unattended-upgrades",
    dest="/etc/apt/apt.conf.d/52unattended-upgrades-local",
)

apt.packages(
    name="Install rsync",
    packages="rsync"
)
