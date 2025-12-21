from io import StringIO
from pathlib import Path, PurePosixPath

from pyinfra import host
from pyinfra.operations import files, systemd
from pyinfra.facts.server import Home

if "tilde_servers" in host.groups:
    public_key_filename = host.data.get("tilde_tunnel_public_key")
    if not isinstance(public_key_filename, str):
        raise ValueError("tilde_tunnel_public_key required.")
    public_key_contents = Path(public_key_filename).read_text().strip()

    # files.block() seems to have trouble with the ~ in ~/.ssh/authorized_keys,
    # so let's spell it out for it.
    home = PurePosixPath(host.get_fact(Home))
    authorized_keys = home / ".ssh" / "authorized_keys"

    # Tilde Town puts the initial signup authorization in authorized_keys2,
    # so this might be the first thing that creates authorized_keys.
    # Make sure we restrict the permissions.
    files.file(
        name="Ensure authorized_keys is present",
        path=str(authorized_keys),
        present=True,
        mode="600",
    )

    # We use the filesblock operation instead of server.user_authorized_keys
    # to make sure we remove old authorizations.
    files.block(
        name="Authorize the public key",
        path=str(authorized_keys),
        # Restrict the authorization to just port-forwarding to mitigate the damage
        # in case someone manages to steal the private key.
        content=f'restrict,command="/sbin/nologin",port-forwarding {public_key_contents}',
        marker="## {mark} ANSIBLE MANAGED BLOCK FOR THELOUNGE TUNNEL ##",
        # We've got some `"` characters in the content, and, disgustingly, pyinfra will drop them
        # unless we specify this. Why is a Python library vulnerable to shell expansion? Who knows.
        try_prevent_shell_expansion=True,
    )

if "thelounge_servers" in host.groups:
    private_key_filename = host.data.get("tilde_tunnel_private_key")
    if not isinstance(private_key_filename, str):
        raise ValueError("tilde_tunnel_private_key required.")

    tilde_connection = host.data.get("tilde_connection")
    if not isinstance(tilde_connection, str):
        raise ValueError("tilde_connection required.")

    files.directory(
        name="Create a folder to hold the private key",
        path="/etc/tilde_tunnel",
        mode="700",
    )

    put_private_key = files.put(
        name="Upload the private key",
        src=private_key_filename,
        dest="/etc/tilde_tunnel/private_key",
        mode="600",
    )

    service_file_contents = (
        Path("files/tilde-tunnel.service")
        .read_text()
        .replace("USER@HOST", tilde_connection)
    )
    put_service_file = files.put(
        name="Create a service file",
        src=StringIO(service_file_contents),
        dest="/etc/systemd/system/tilde-tunnel.service",
        mode="644",
    )

    systemd.service(
        name="Make sure the service is enabled and running",
        service="tilde-tunnel",
        enabled=True,
        running=True,
    )

    systemd.service(
        name="Reload unit files and restart the service to pick up config changes",
        service="tilde-tunnel",
        daemon_reload=True,
        restarted=True,
        _if=lambda: put_private_key.did_change() or put_service_file.did_change()
    )
