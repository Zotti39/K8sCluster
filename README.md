# K8sCluster

# Documentação para Configuração de Master Node e Cluster Kubernetes em uma Máquina Virtual

## Introdução

Este documento descreve os passos para configurar um nó mestre (Master Node) e um cluster Kubernetes em uma máquina virtual utilizando um script de inicialização. O script realiza a instalação e configuração dos componentes necessários para criar um ambiente Kubernetes funcional. Todos os comando aqui descritos foram passados na maquina utilizando o usuario root do sistema mas pode ser feito passando `root` antes de cada comando

## Pré-requisitos
- Máquina virtual configurada com um sistema operacional Linux. (Utilizei Debian)
- Acesso de superusuário (root) na máquina virtual.
- Executar o script `firewallScript.sh` presente no repositorio para liberar as portas da maquina


## Passos para Configuração:
1. Preparação do Sistema
O script começa carregando módulos do kernel e configurando parâmetros do sistema necessários para o Kubernetes.

        #!/bin/bash
        cat <<EOF | tee /etc/modules-load.d/k8s.conf
        overlay
        br_netfilter
        EOF

        modprobe overlay
        modprobe br_netfilter

        cat <<EOF | tee /etc/sysctl.d/k8s.conf
        net.bridge.bridge-nf-call-iptables  = 1
        net.bridge.bridge-nf-call-ip6tables = 1
        net.ipv4.ip_forward                 = 1
        EOF

        sysctl --system

2. Instalação do Containerd
O Containerd é um gerenciador de containers que será utilizado pelo Kubernetes.

        wget https://github.com/containerd/containerd/releases/download/v1.7.11/containerd-1.7.11-linux-amd64.tar.gz
        tar Cxzvf /usr/local containerd-1.7.11-linux-amd64.tar.gz
        mkdir /etc/containerd
        containerd config default > config.toml
        cp config.toml /etc/containerd
        wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
        cp containerd.service /etc/systemd/system/
        systemctl daemon-reload
        systemctl enable --now containerd

3. Instalação do Runc e Plugins CNI
Runc é um executor de containers e os plugins CNI são necessários para a configuração de redes no Kubernetes.


        wget https://github.com/opencontainers/runc/releases/download/v1.1.10/runc.amd64
        install -m 755 runc.amd64 /usr/local/sbin/runc
        wget https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz
        mkdir -p /opt/cni/bin
        tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.4.0.tgz

3.1. Agora pe necessario trocar o parametro `SistemdCgroup` para `true` no arquivo `/etc/containerd/config.toml`

4. Instalação do Kubernetes
O script adiciona o repositório do Kubernetes e instala as versões específicas do kubelet, kubeadm e kubectl.

        systemctl restart containerd
        apt-get update
        apt-get install -y apt-transport-https ca-certificates curl gpg
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
        apt-get update
        apt-get install -y kubelet=1.28.4-1.1 kubeadm=1.28.4-1.1 kubectl=1.28.4-1.1
        apt-mark hold kubelet kubeadm kubectl
        systemctl start kubelet
        systemctl enable kubelet

5. Configuração da Rede e Inicialização do Cluster
O script desativa a troca de memória (swap), configura o Calico como plugin de rede e inicia o cluster Kubernetes.

        swapoff -a
        sed -i '/^\/swap.img/s/^/#/' /etc/fstab

6. Proxima parte será realizada após o comando `kubeadm init` que definirá a maquina como o controlPlane / masterNode. Para os WorkerNodes esse passo não deve ser feito, e sim utilizar o comando `kubeadm join <TOKEN>` que será parte do output do comando init no master.

        mkdir -p $HOME/.kube
        cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
        chown $(id -u):$(id -g) $HOME/.kube/config

7. Instala o Calico como adds-on do cluster

        curl https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml -O
        kubectl apply -f calico.yaml

### Conclusão
Após seguir os passos descritos neste documento e executar os scripts, você terá um nó mestre e um cluster Kubernetes funcionais em sua máquina virtual. Você pode agora começar a criar e gerenciar seus aplicativos containerizados no ambiente Kubernetes configurado.