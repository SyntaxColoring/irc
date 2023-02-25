# SSH host config (~/.ssh.config)

```
host personal-thelounge
	Hostname thelounge.marrone.nyc
	IdentityFile ~/.ssh/id_personal_aws
	User ubuntu
	# Hack to allow us to replace the instance without having to modify the known_hosts file each time.
	StrictHostKeyChecking no
```


# Stop services to prepare for maintenance

```bash
ssh $HOST_CONNECTION_OPTIONS sudo systemctl stop thelounge
```


# Download config and data files

```bash
scp -r "$HOST_CONNECTION_OPTIONS:/var/opt/thelounge" thelounge_instance_files
```

Inspect the files to make sure everything is there before you delete the instance.

Note that we don't bother saving Caddy's data directory, for fear of screwing up file permissions on something.
I think this is fine despite Caddy documentation cautioning not to treat those files as ephemeral.
Let's Encrypt has a rate limit of 50 new certificates per domain per week, which we're unlikely to hit.


# Upload config and data files


```bash
ssh $HOST_CONNECTION_OPTIONS rm -rf /tmp/upload
scp -r thelounge_instance_files "$HOST_CONNECTION_OPTIONS:/tmp/upload"
ssh $HOST_CONNECTION_OPTIONS 'sudo rm -rf /var/opt/thelounge && cp -r /tmp/upload /var/opt/thelounge'
```


# Start services back up

```bash
ssh $HOST_CONNECTION_OPTIONS sudo systemctl start thelounge
```
