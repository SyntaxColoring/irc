# Introduction

This is a Terraform module to provide a small AWS EC2 instance capable of hosting The Lounge.

# Details

* Stock Ubuntu image
* Exposed to the Internet over IPv4 and IPv6
* Placed in a standalone Virtual Private Cloud to avoid polluting your default one

At the time of writing, this costs around $3 USD per month, depending on your choice of AWS region and whether you opt in to any AWS savings plans.

# Setup after `terraform apply`

## Ping test

The instance should respond to `ping`s at its public IPv4 and IPv6 addresses.

## Setting up SSH access

To get SSH access, any time you need to connect, use [AWS Instance Connect](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/Connect-using-EC2-Instance-Connect.html) to push a short-lived key to the instance.
For security and operational simplicity, the instance is not configured with any long-lived SSH authorizations.

There are many ways to do this, but here's my preferred one:

1. Make sure you have the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide) installed and configured with your credentials.
2. Use `ssh-keygen` to make a key pair.
3. Copy [`ssh_config/proxy-to-ec2.sh`](ssh_config/proxy-to-ec2.sh) into your `~/.ssh/` directory.
4. Copy [`ssh_config/example_ssh_config`](ssh_config/example_ssh_config) into your `~/.ssh/config` file, adjusting the values as appropriate.

You should now be able to `ssh`, `scp`, etc. into the instance.
Your SSH key will be short-term authorized each time, using your AWS credentials. You can freely delete and replace the key pair any time.

This will be transparent to Ansible, working like any normal SSH connection.

Alternative ways to connect include:

* [`mssh`](https://github.com/aws/aws-ec2-instance-connect-cli).
  But that [doesn't work with Ansible](https://github.com/aws/aws-ec2-instance-connect-cli/issues/24), so then you'd also need an Ansible connection plugin like [mpieters3/ansible-eci-connector](https://github.com/mpieters3/ansible-eci-connector).
* `aws ssm start-session` and the [`aws_ssm`](https://docs.ansible.com/ansible/latest/collections/community/aws/aws_ssm_connection.html) Ansible connection plugin.
  But that requires extra permissions on the instance profile and an S3 bucket for file transfer.
  And the connection plugin is [slow](https://github.com/ansible-collections/community.aws/issues/1148) and has [permissions issues](https://github.com/ansible-collections/community.aws/issues/853).

## Setting up The Lounge

Continue with the instructions in [`../ansible`](../ansible).

# Security

The instance is exposed to the Internet. Take appropriate measures to protect it.

## Package updates

The Ubuntu image downloads and installs package updates automatically, unattended. However, sometimes this requires restarting services, and it does *not* automatically do that.

To make sure the instance is running updated software, you periodically need to either:

* Reboot the whole instance, either through `ssh` or the AWS web console.
* Or, SSH in and run the following:
  ```bash
  needrestart -r -l # List everything that needs to be restarted.
  needrestart -r a # Restart those things.
  ```

# Destroying the instance (`terraform destroy`)

The instance is intended to be long-lived.
Destroying it will also destroy the user configurations and chat logs that you have in The Lounge.
See the instructions in [`../ansible`](../ansible) to download them first.
