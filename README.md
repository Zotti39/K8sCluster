# K8sCluster

1. [Cluster em MaquinaVirtual](#vm)
2. [Cluster em AWS EC2s](#ec2)

# Documentação para Configuração de Master Node e Cluster Kubernetes em uma Máquina Virtual

<div id='vm'/> 

## Introdução
### Arquivos na pasta vmVirtualBox
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

<div id='ec2'/> 

# Documentação para Configuração de Cluster Kubernetes em Instâncias EC2 na AWS

### Introdução
### Arquivos na pasta EC2s
### baseado em: https://mrmaheshrajput.medium.com/deploy-kubernetes-cluster-on-aws-ec2-instances-f3eeca9e95f1

Este documento descreve os passos para configurar um cluster Kubernetes utilizando instâncias EC2 na AWS com OS ubuntu. O script fornecido automatiza a configuração do MasterNode, preparando o ambiente para a instalação do Kubernetes e a configuração do plugin de rede Calico. Ao utilizar o script `script1AWS.sh` para criar a instancia ec2(que deve ser do tipo `t3.small` ou outro type que tenha > 2Vcpus && > 2Gib VRAM), serão criados scripts secundarios dentro da instancia, que facilitarão o processo da configuração manual do cluster, basta executar os scripts na ordem correta, e seguir os passo descritos dentro do arquivo README.md que estará diposnivel no diretorio `/home/ubuntu` dentro da instancia e o cluster será iniciado.

### Pré-requisitos

- Conta AWS com permissões para criar instâncias EC2.
- Chave SSH para acessar as instâncias EC2.
- Acesso SSH às instâncias EC2 após a criação.
- Passos para Configuração

1. Preparação do Ambiente

        # Desabilitar Swap e Configurar Aliases
        sudo swapoff -a
        # Adicione seus aliases preferidos ao arquivo .bashrc
        sudo echo "
        alias k='kubectl'
        alias c='clear'
        alias update='sudo apt-get update'
        " >> ~/.bashrc
        source ~/.bashrc
        Adicionar IP Público aos Hosts
        bash
        Copy code
        sudo chmod 666 /etc/hosts 
        ip=$(curl http://checkip.amazonaws.com)
        echo "$ip control-plane" >> /etc/hosts

2. Configuração de Containerd
Abaixo criamos o scritp que configura o Containerd, que será utilizado pelo Kubernetes como gerenciador de containers.

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
        sudo apt-get update
        sudo apt-get -y install containerd
        sudo mkdir -p /etc/containerd
        sudo containerd config default | sudo tee /etc/containerd/config.toml
        sudo systemctl restart containerd
        ' | sudo tee /home/ubuntu/scriptContainerd1.sh
        sudo chmod u+x /home/ubuntu/scriptContainerd1.sh

3. Instalação do Kubernetes
Abaixo criamos o scritp que instala o Kubernetes, fixando a versão dos pacotes para evitar atualizações indesejadas.

        echo '#!/bin/bash
        echo "Make script executable using chmod u+x FILE_NAME.sh"
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl gpg
        curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo apt-get update
        sudo apt-get install -y kubelet kubeadm kubectl
        sudo apt-mark hold kubelet kubeadm kubectl
        sudo chmod 666 /etc/containerd/config.toml
        ' | sudo tee /home/ubuntu/scriptKube2.sh
        sudo chmod u+x /home/ubuntu/scriptKube2.sh

4. Configuração Final e Inicialização do Cluster
Após executar os scripts para Containerd e Kubernetes, siga as instruções abaixo para finalizar a configuração e iniciar o cluster. Fiz um miniREADME dentro da instancia para auxiliar no processo

        echo '### After running scriptContainerd1.sh and scriptKube2.sh do the following:

        ### To configure containerd to use the systemd driver, set the following option in /etc/containerd/config.toml:
        version = 2
        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        SystemdCgroup = true

        ### And after that restart kubelet an containerd services using:
        sudo service containerd restart
        sudo service kubelet restart

        ### Start the cluster using `sudo kubeadm init` and follow the instructions its output will give you
        ### To make it easier I will let available a file `scriptInit3.sh` with the commands you have to run after the `kubeadm init`
        ### It will be necessary to remove the dots after the $ though, otherwise it won't work

        ### Now you can run the Calico script to start the add-on

        ### To retrieve the join token for the kubeadm use the following command:
        kubeadm token create --print-join-command

        ### Also remember to change the name for the ip on /etc/hosts to worker node in case this is the working node
        ' | sudo tee /home/ubuntu/README.md

5. Inicialização do Cluster Kubernetes
Após configurar o Containerd e o Kubernetes, você pode iniciar o cluster e configurar o plugin de rede Calico.

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

6. 
### Conclusão

Após seguir os passos descritos neste documento e executar os scripts, você terá um cluster Kubernetes funcional em instâncias EC2 com OS ubuntu na AWS. 