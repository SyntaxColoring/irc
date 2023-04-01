# Setup

```bash
python3 -m venv administration/venv
source administration/venv/activate
pip install -r administration/requirements.txt
```


# Getting a shell

```bash
mssh ubuntu@$(terraform -chdir=../../.. output --raw thelounge_instance_id) --region us-east-1
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
This risks hitting Let's Encrypt's rate limit of 5 renewals per week.
If this happens, Caddy should fall back to ZeroSSL automatically.


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
