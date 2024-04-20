#!/bin/bash
## Before executing this script change thee parameter for SystemdCgroup to 'true' on the file /etc/containerd/config.toml
systemctl restart containerd
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet=1.28.4-1.1 kubeadm=1.28.4-1.1 kubectl=1.28.4-1.1
apt-mark hold kubelet kubeadm kubectl
systemctl start kubelet
systemctl enable kubelet
swapoff -a
sed -i '/^\/swap.img/s/^/#/' /etc/fstab

