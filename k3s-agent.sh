#!/bin/bash

TOKEN=""
while [ -z "$TOKEN" ]
do
	sleep 1
	TOKEN=$(echo sudo cat /var/lib/rancher/k3s/server/node-token | ssh -i /home/ubuntu/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@198.19.0.1 | grep '::server:')
done

echo "Token acquired: $TOKEN"

while [ ! -d /var/lib/rancher ]
do
	curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.18.10+k3s1" K3S_URL=https://198.19.0.1:6443 K3S_TOKEN=$TOKEN sh -
	sleep 1
done

echo Installation Completed.

