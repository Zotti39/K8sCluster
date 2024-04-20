#!/bin/bash

sudo swapoff -a

### Adiciona IP publico aos hosts
sudo chmod 666 /etc/hosts 
ip=$(curl http://checkip.amazonaws.com)
echo "$ip control-plane" >> /etc/hosts

echo '#!/bin/bash
sudo apt-get update
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system
lsmod | grep br_netfilter
lsmod | grep overlay
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
sudo apt-get update
sudo apt-get -y install containerd
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
' | sudo tee /home/ubuntu/scriptContainerd1.sh
sudo chmod u+x /home/ubuntu/scriptContainerd1.sh

echo '#!/bin/bash
echo "Make script executable using chmod u+x FILE_NAME.sh"
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
echo "Installing latest versions"
sudo apt-get install -y kubelet kubeadm kubectl
echo "Fixate version to prevent upgrades"
sudo apt-mark hold kubelet kubeadm kubectl
sudo chmod 666 /etc/containerd/config.toml
' | sudo tee /home/ubuntu/scriptKube2.sh
sudo chmod u+x /home/ubuntu/scriptKube2.sh


echo '### After runing scriptContainerd1.sh and scriptKube2.sh do the following:

### To configure containerd to use the systemd driver, set the following option in /etc/containerd/config.toml:
version = 2
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true

### And after that restart kubelet an containerd services using:
sudo service containerd restart
sudo service kubelet restart

### The next steps are only required for the master node, the worker node configuration ends here!

### Start the cluster using `sudo kubeadm init` and follow the instructions its output will give you
### To make it easier i will let available a file `scriptInit3.sh` with the commands you have to run after the `kubeadm init` command be passed

### Now you can run the Calico script to start de adds-on, and only after this start joining your worker pods to the cluster

### To retrieve the join token for the the kubeadm use the following command:
kubeadm token create --print-join-command

### Also remember to change the name for the ip on /etc/hosts to worker node in case this is the working node
' | sudo tee /home/ubuntu/README.md

echo '#!/bin/bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
' | sudo tee /home/ubuntu/scriptInit3.sh
sudo chmod u+x /home/ubuntu/scriptInit3.sh

echo '#!/bin/bash
curl https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml -O
kubectl apply -f calico.yaml
' | sudo tee /home/ubuntu/scriptCalico4.sh
sudo chmod u+x /home/ubuntu/scriptCalico4.sh

### Add some os the alias I'm used to work with, fell free to remove or add yours to this part if you wish
sudo echo "
alias k='kubectl'
alias c='clear'
alias update='sudo apt-get update'
" >> ~/.bashrc
source ~/.bashrc