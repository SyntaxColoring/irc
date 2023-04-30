#!/bin/bash

set -euo pipefail
set -o xtrace

remote_user="$1"
network_address="$2"
port="$3"
ec2_instance_id="$4"
aws_region="$5"
public_key_path="$6"

>&2 aws ec2-instance-connect send-ssh-public-key \
    --instance-os-user "$remote_user" \
    --instance-id "$ec2_instance_id" \
    --region "$aws_region" \
    --ssh-public-key "file://$public_key_path"

nc "$network_address" "$port"
