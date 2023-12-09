This project originated from my desire to experiment with various Container Network Interface (CNI) and Service Mesh projects for Kubernetes, such as Istio, Cilium, Calico, and others. The intention was to carry out these experiments on my personal Linux/Ubuntu workstation, eliminating the need for deployment on a cloud provider or a Homelab, which tends to consume a considerable amount of energy.

Previously, I had been utilizing [this project by Tigera](https://github.com/tigera/ccol1/tree/main), but it deployed an outdated K3s version (v1.18.10+k3s1). Consequently, I made the decision to update the cloud-init scripts to facilitate the deployment of a more recent K3s version.

In essence, the primary goal of this project is to establish a Lightweight Kubernetes cluster (K3s) on Ubuntu virtual machines launched through multipass.

These steps have undergone thorough testing in an environment meeting the following conditions:
```
OS/Kernel versions: Linux 6.2.0-36-generic #37~22.04.1-Ubuntu
multipass 1.22.2
```
[This is the original](https://github.com/tigera/ccol1/tree/main) repo hosting the project. This project deploys a K3s Kubernetes cluster with the following versions:  
```
Calico and calicoctl v3.21.4
Kubectl 1.19.2
K3s v1.18.10+k3s1
```

In my project, the components have been updated to:
```
Calico and calicoctl v3.25.2
Kubectl 1.25.0
K3s v1.25.13+k3s1
K3s server is launched with ServiceLB enabled and traefik disabled. 
```

In case a new version is required, the user must updated the cloud-init files passed to multipass to bootstrap the VMs, more about this below, let's now focus on how to deploy the cluster.

**Steps to create the K3S cluster**

1. Clone the repository: 
```
git clone https://github.com/sadieleob/k3s-multipass.git
```

2. Create the VMs with multipass, cloud-init will bootstrap the node and install Kubernetes components:
```
multipass launch -n master-k8s -m 2048M 20.04 --cloud-init ./control-init.yaml
multipass launch -n worker-1-k8s 20.04 --cloud-init ./node1-init.yaml
multipass launch -n worker-2-k8s 20.04 --cloud-init ./node2-init.yaml
multipass launch -n host1 20.04 --cloud-init ./host1-init.yaml
```

3. Adding more nodes to the cluster:
- Copy node3-init.yaml and change the following files: /etc/dynamicaddress.sh and /etc/cloud/templates/hosts.debian.tmpl
- In /etc/dynamicaddress.sh update the ip address: "printf 'network:\n  ethernets:\n    %s:\n      addresses: [ 198.19.0.4/20 ]\n  version: 2' $IFACE | tee /etc/netplan/51-static.yaml"
- In /etc/cloud/templates/hosts.debian.tmpl add the new node to the /etc/hosts

**NOTE**: Please make sure to place the cloud-init files in your home directory because [snap confinement](https://github.com/canonical/multipass/issues/2725) could deny access to the files and you could hit the following error:
```
"error loading cloud-init config: bad file"
```
SSH into host1 and confirm that the nodes were created and Kubernetes components were installed. However, please note that no CNI plugin has been installed yet, so it is expected that the nodes appear as **NotReady**:
```
multipass list 
Name                    State             IPv4             Image
host1                   Running           10.78.117.178    Ubuntu 20.04 LTS
master-k8s              Running           10.78.117.95     Ubuntu 20.04 LTS
worker-1-k8s            Running           10.78.117.100    Ubuntu 20.04 LTS
worker-2-k8s            Running           10.78.117.208    Ubuntu 20.04 LTS

multipass shell host1

kubectl get node
NAME           STATUS     ROLES                  AGE   VERSION
master-k8s     NotReady   control-plane,master   18m   v1.25.13+k3s1
worker-1-k8s   NotReady   <none>                 17m   v1.25.13+k3s1
worker-2-k8s   NotReady   <none>                 16m   v1.25.13+k3s1
```

**Installing Calico**
```
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.2/manifests/tigera-operator.yaml

cat <<EOF | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
  containerIPForwarding: Enabled
  ipPools:
   - cidr: 198.19.16.0/21
     natOutgoing: Enabled
     encapsulation: None
EOF
```

Up to this point, we should have a K3s cluster with 1 control-plane and 2 worker nodes in READY status:
```
kubectl get nodes
NAME           STATUS   ROLES                  AGE   VERSION
master-k8s     Ready    control-plane,master   98m   v1.25.13+k3s1
worker-1-k8s   Ready    <none>                 97m   v1.25.13+k3s1
worker-2-k8s   Ready    <none>                 96m   v1.25.13+k3s1
```

**Load Balancer Implementation**

Initially, MetalLB was tested to provide LB-type Service support in K3s but since the version 3.18 of Calico, [MetalLB has limited integration with Calico](https://metallb.universe.tf/configuration/calico/), so it was decided to go with the default [***ServiceLB***](https://docs.k3s.io/networking#service-load-balancer) Load Balancer. For further details on how ServiceLB works please refer to the [documentation](https://docs.k3s.io/networking#how-servicelb-works). 
  
**Installing Istio Service Mesh 1.17.2**

1. Download the istio binary:
```
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.17.2 sh -
``` 
2. Copy the istioctl binary to the /usr/local/bin and install the istio DEMO profile:
```
cd istio-1.17.2/bin/
sudo cp istioctl /usr/local/bin/
istioctl version
istioctl x precheck <Optional>
istioctl profile list  <Optional>
istioctl install --set profile=demo
```

Enjoy playing with ISTIO!

References:

- https://github.com/tigera/ccol1/tree/main
- https://github.com/k3s-io/k3s
- https://github.com/sadieleob/k3s-multipass
- https://metallb.universe.tf/
- https://metallb.universe.tf/configuration/k3s/
- https://docs.k3s.io/networking#how-servicelb-works
