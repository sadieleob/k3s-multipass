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
```

In case a new version is required, the user must updated the cloud-init files passed to multipass to bootstrap the VMs, more about this below, 
let's now focus on how to deploy the cluster.

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

**NOTE**: Please make sure to place the cloud-init files in your home directory because snap confinement could deny access to the files and you could hit the following error:
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

**Installing Metal-LB**

Metal-LB is has to be installed to provide LoadBalancer-type Kubernetes services, please refer to [Metal-LB documentation](https://metallb.universe.tf/) for additional details.

```
MetalLB_RTAG=$(curl -s https://api.github.com/repos/metallb/metallb/releases/latest|grep tag_name|cut -d '"' -f 4|sed 's/v//')

wget https://raw.githubusercontent.com/metallb/metallb/v$MetalLB_RTAG/config/manifests/metallb-native.yaml

kubectl apply -f metallb-native.yaml

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: homelab
  namespace: metallb-system
spec:
  addresses:
  - IP_ADDRESS_RANGE <Example: 10.78.117.100-10.78.117.200>
EOF
```

**NOTE**: In my case, multipass is using the qemu driver, and the bridge interface created to enable the VM network is mpqemubr0 with a CIDR 10.78.117.0/24, so I have to choose an IP address pool for Metal-LB in that range. You can check the Multipass network by looking at the bridge's interface:
 
```
ifconfig mpqemubr0  
mpqemubr0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.78.117.1  netmask 255.255.255.0  broadcast 10.78.117.255
        inet6 fe80::5054:ff:febb:c35f  prefixlen 64  scopeid 0x20<link>
        ether 52:54:00:bb:c3:5f  txqueuelen 1000  (Ethernet)
        RX packets 3813204  bytes 313282035 (313.2 MB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 11715607  bytes 14788240603 (14.7 GB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

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
[1] https://github.com/tigera/ccol1/tree/main
[2] https://github.com/k3s-io/k3s
[3] https://github.com/sadieleob/k3s-multipass
