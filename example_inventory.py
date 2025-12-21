thelounge_servers = [
    (
        "thelounge",  # SSH host, e.g. as present in ~/.ssh/config.
        {
            # Input to our scripts:
            "fqdn": "thelounge.example.com",  # Internet-accessible name.
            # "tilde_connection": "yourusername@tilde.town",  # If setting up a Tilde Town tunnel.

            # SSH connection options, defined by pyinfra:
            "ssh_key": "/home/yourusername/.ssh/thelounge_private_key",  # Declaring this explicitly seems to help pyinfra use it when it's password-protected.
            "ssh_user": "root",  # These scripts expect to SSH in as root.
        },
    )
]

tilde_servers = [
    # If setting up a Tilde Town tunnel:

    # (
    #     "tilde.town",
    #     {
    #         "ssh_key": "/home/yourusername/.ssh/keys/tilde_town_private_key",
    #     },
    # )
]
