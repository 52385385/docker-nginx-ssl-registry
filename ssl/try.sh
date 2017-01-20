#!/bin/bash
if [ -z $1 ]; then
    echo "Usage: $0 IP-or-DNS"
    exit;
fi

if [ ! -d "/etc/docker/certs.d/$1" ]; then
    mkdir -pv /etc/docker/certs.d/$1
fi

echo yes | cp ca.crt /etc/docker/certs.d/$1/
docker login --username test --password test $1
