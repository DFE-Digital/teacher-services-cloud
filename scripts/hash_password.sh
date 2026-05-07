#!/bin/bash
# hash_password.sh
username=$1
password=$2

set -eu

if [ -z "$username" ] || [ -z "$password" ]; then
    echo "Error: Both username and password are mandatory."
    exit 1
fi
# Ensure the password is hashed correctly and output is formatted as expected
hashed_password=$(htpasswd -nbB "$username" "$password")
echo "{\"hashed_password\":\"$hashed_password\"}"
