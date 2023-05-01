# Introduction

These are Ansible playbooks to set up a server to host The Lounge.

# Prerequisites

* Some Ubuntu-ish server.
  For the exact version that I use, see [`../tf`](../tf).
* The server must be accessible over the Internet and have some domain pointing to it.
  This is required for automatically setting up TLS.


# Example inventory file

```yaml
thelounge:
  hosts:
    thelounge.example.com:
  vars:
    ansible_ssh_pipelining: true
   
    # Currently required.
    # Passed along to the certificate authority.
    email: you@example.com

    # Set to true if you're experimenting,
    # to avoid hitting the certificate authority's rate limits.
    # The site will be served from an untrusted staging certificate.
    # https://letsencrypt.org/docs/staging-environment/
    tls_staging: false

# Optional. Only needed if you're using tunnel_to_tilde.yaml.
tilde_town:
  hosts:
    tilde.town:
```


# Playbook details


## [`provision.yaml`](provision.yaml)

Run this first.
This turns a bare Ubuntu server into a useful server for The Lounge.

* Installs The Lounge and configures it as a system service.
* Installs Caddy and configures it as a reverse proxy to serve The Lounge over HTTPS.

The Lounge will run in a Docker container.
When you need to manually run a `thelounge` CLI command, run it through the wrapper `thelounge-docker-exec`.

For example, to add a user, SSH in and run:

```shell
sudo thelounge-docker-exec thelounge add my_new_username
```

## [`download_thelounge_data.yaml`](download_thelounge_data.yaml) and [`upload_thelounge_data.yaml`](upload_thelounge_data.yaml)

These save or restore an archive of your chat logs and user configurations.

## [`tunnel_to_tilde.yaml`](tunnel_to_tilde.yaml) 

This playbook is optional.
It sets things up so you can use The Lounge to connect to [Tilde Town](https://tilde.town/)'s [IRC network](https://tilde.town/wiki/socializing/irc/), assuming you already have an account there.


### Settings for The Lounge

After running this playbook,
add Tilde Town's network through The Lounge's web UI with these settings:

* Server: `localhost`
* Port: 6667
* Use secure connection (TLS): Unchecked
* Authentication: No authentication


### Details

Inspired by [~nick's writeup](https://tilde.town/~nick/sshtunnel.html), this works by creating a persistent SSH tunnel from your server hosting The Lounge to Tilde Town.

Specifically:

1. It generates a new SSH key pair.

2. It authorizes the public key on your Tilde Town account.

   In other words, it logs in to Tilde Town (using your normal, preexisting credentials) and adds the new public key to `~/.ssh/authorized_keys`.

   In case someone nefarious gets their hands on the private key, it restricts connections so they only have the minimum power required to access IRC.
   For example, they can't run shell commands.

3. It gives the private key to your server hosting The Lounge.

   It sets up a service that uses the private key to open the tunnel, and it exposes that tunnel to other processes on the server.

The key pair will be kept locally so if you run the playbook again, it will be idempotent.
You can also try using it to SSH in to Tilde Town to confirm that it won't let you do things like run shell commands.

Deleting the locally-saved key pair is safe.
If you run the playbook again afterwards, it will generate another key pair and replace the old one on Tilde Town and The Lounge.
You can do this to roll credentials if you believe someone nefarious has been able to access the private key.
