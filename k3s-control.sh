#!/bin/bash

while [ ! -d /var/lib/rancher ]
do
	curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="v1.25.13+k3s1" INSTALL_K3S_EXEC="--flannel-backend=none --cluster-cidr=198.19.16.0/20 --service-cidr=198.19.32.0/20 --write-kubeconfig-mode 664 --disable-network-policy" sh -
	sleep 1
done

echo Installation Completed.

