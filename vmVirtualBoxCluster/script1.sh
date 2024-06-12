#!/bin/bash
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sysctl --system

# containerd
wget https://github.com/containerd/containerd/releases/download/v1.7.11/containerd-1.7.11-linux-amd64.tar.gz
tar Cxzvf /usr/local containerd-1.7.11-linux-amd64.tar.gz
mkdir /etc/containerd
containerd config default > config.toml
cp config.toml /etc/containerd
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
cp containerd.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now containerd
wget https://github.com/opencontainers/runc/releases/download/v1.1.10/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc
wget https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz
mkdir -p /opt/cni/bin
tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.4.0.tgz

