# Introduction

These are scripts that I use to host my personal instance of [The Lounge](https://thelounge.chat/).

# Prerequisites

* Some recent Debian-ish server.
* The server must be accessible over the Internet and have some domain pointing to it.
  This is required for automatically setting up TLS.

# Setup

1. `python -m venv venv`
2. `venv/bin/pip install -r requirements.txt`
3. Copy `example_inventory.py` to `inventory.py` and fill it in.

# Script details

## `provision`

Run this first.
This turns a bare Debian server into a useful server for The Lounge.

* Installs the current Node.js LTS from NodeSource.
* Installs The Lounge and configures it as a system service.
* Installs Caddy and configures it as a reverse proxy to serve The Lounge over HTTPS.
* Configures automatic security updates. (With automatic restarts, when needed.)

Then, to add a user, SSH in and run:

```shell
sudo thelounge add my_new_username
```

## `data-download` and `data-upload`

These save or restore an archive of chat logs and user configurations.

## `tunnel-to-tilde`

This is optional.
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
