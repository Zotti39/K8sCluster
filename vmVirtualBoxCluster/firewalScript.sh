# /bin/bash
apt-get update
apt-get install ufw -y
systemctl enable ufw

ufw allow 22/tcp               # SSH
ufw allow 6443/tcp             # Kubernetes API Server
ufw allow 2379:2380/tcp        # etcd server client API
ufw allow 10250/tcp            # Kubelet API
ufw allow 10251/tcp            # Kubelet Service
ufw allow 10252/tcp            # Kubelet Proxy
ufw allow 30000:32767/tcp      # NodePort Services (opcional, se você planeja usar NodePort)