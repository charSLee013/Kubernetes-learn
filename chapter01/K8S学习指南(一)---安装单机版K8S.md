### K8S学习指南(一)---安装单机版K8S
##### `Kubernetes` 概述
> `Kubernetes`(以下简称K8S) 是一个完备的分布式系统支撑平台。包含安全防护，负载均衡，多粒度的资源配额管理能力.
> 以下介绍K8S组成部分

#### **Service**
* `Service`是分布式集群架构的核心,一个`Service`对象拥有如下关键特征.
    - 拥有一个唯一指定的名字(比如**redis-server**).
    - 拥有一个虚拟IP(**Cluster Ip或VIP**) 和端口号.
    - 能够提供某种远程服务能力.
    - 能被映射到提供这种服务能力的一组容器应用上.

#### **Pod**
* `Pod`是K8S最小的管理元素.
    - 它是一个或多个容器的组合。这些容器共享存储、网络和命名空间，以及如何运行的规范
    - 一个`Pod`的共享上下文是`Linux`命名空间、`cgroups`和其它潜在隔离内容的集合
    - 在不同`Pod`中的容器，拥有不同的`IP`地址，因此不能够直接在进程间进行通信。容器间通常使用`Pod IP`地址进行通信.
    - `Pod`运行在节点`Node`的环境上.
    - 每个`Pod`运行一个特殊容器`Pause`.其他则为业务容器.
    - 这些业务容器共享`Pause`容器的网络栈和`Volume`挂载卷.


#### **Node**
* Node是Pod真正运行的主机，可以物理机，也可以是虚拟机.
    - 为了管理Pod，每个Node节点上至少要运行container runtime（比如docker或者rkt）、kubelet和kube-proxy服务.
    - 这些进程负责`Pod`的创建,启动,监控,重启,销毁,以及实现软件模式的负载均衡器.
    - 节点的状态信息包含
        - Addresses. 描述网络地址
        - Condition. 描述所有`Running`节点的状态
        - Capacity. 描述节点上可用硬件资源:`CPU`,`RAM`,`DISK`,最大`Pod`数等.
        - Info. 描述节点基础信息.如内核版本,OS名称等.


--------------------------------------------

### 搭建`Kubernetes`
#### 系统准备
    * OS: Ubuntu 18.04.1 LTS X86_64
    * USER: root
    * CPU: 2+   (一定要 2croe +,否则创建minikube 创建的时候会报错)
    * RAM: 2Gib+

> 机器建议使用能连接上谷歌的,因为K8S很多包和源都在海外.

#### 搭建步骤
1. 关闭`swap`
```Bash
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

2. 刷新`apt list`和更新组件
```Bash
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget apt-transport-https -y
```

3. 安装`docker`
```Bash
## install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update && sudo apt install -y docker-ce

## 设置开机自启动
sudo systemctl enable docker
systemctl start docker
```

4. 安装`minikube`(请确保能连接上Google)
```Bash
wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x ./minikube-linux-amd64
mkdir -p /usr/local/bin/
cp minikube-linux-amd64 /usr/local/bin/minikube

## 查看版本
sudo minikube version

minikube version: v1.5.2
commit: 792dbf92a1de583fcee76f8791cff12e0c9440ad-dirty
```

5. 安装`Kubectl` `kubeadm` `kubernetes-cni`
```Bash
# 先添加密钥
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install kubectl -y
sudo apt install -y kubeadm  kubernetes-cni

## 查看版本号
kubectl version -o json

{
  "clientVersion": {
    "major": "1",
    "minor": "16",
    "gitVersion": "v1.16.3",
    "gitCommit": "b3cbbae08ec52a7fc73d334838e18d17e8512749",
    "gitTreeState": "clean",
    "buildDate": "2019-11-13T11:23:11Z",
    "goVersion": "go1.12.12",
    "compiler": "gc",
    "platform": "linux/amd64"
  }
}
```

6. 使用`minikube`安装单机版`K8S`
```Bash
## minikube cleanup
minikube delete
# debug

## --vm-driver=none  不使用虚拟机而是用本机,会降低安全性
export CHANGE_MINIKUBE_NONE_USER=true
minikube start --vm-driver=none
# minikube start --alsologtostderr -v=8    ## debug

* minikube v1.5.2 on Ubuntu 18.04
* Running on localhost (CPUs=2, Memory=3784MB, Disk=50331MB) ...
* OS release is Ubuntu 18.04.1 LTS
* Preparing Kubernetes v1.16.2 on Docker '19.03.5' ...
  - kubelet.resolv-conf=/run/systemd/resolve/resolv.conf
* Downloading kubeadm v1.16.2
* Downloading kubelet v1.16.2
* Pulling images ...
* Launching Kubernetes ... 
* Configuring local host environment ...
* 
! The 'none' driver provides limited isolation and may reduce system security and reliability.
! For more information, see:
  - https://minikube.sigs.k8s.io/docs/reference/drivers/none/
* 
! kubectl and minikube configuration will be stored in /root
! To use kubectl or minikube commands as your own user, you may need to relocate them. For example, to overwrite your own settings, run:
* 
  - sudo mv /root/.kube /root/.minikube $HOME
  - sudo chown -R $USER $HOME/.kube $HOME/.minikube
* 
* This can also be done automatically by setting the env var CHANGE_MINIKUBE_NONE_USER=true
* Waiting for: apiserver
* Done! kubectl is now configured to use "minikube"
```

--------------------------------
#### 检查安装组件的版本
##### 检查集群状态
```Bash
#kubectl cluster-info

Kubernetes master is running at https://172.19.0.15:8443
KubeDNS is running at https://172.19.0.15:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

###### 检查`Kubectl`的默认配置
```Bash
# kubectl config view

apiVersion: v1
clusters:
- cluster:
    certificate-authority: /root/.minikube/ca.crt
    server: https://172.19.0.15:8443
  name: minikube
contexts:
- context:
    cluster: minikube
    user: minikube
  name: minikube
current-context: minikube
kind: Config
preferences: {}
users:
- name: minikube
  user:
    client-certificate: /root/.minikube/client.crt
    client-key: /root/.minikube/client.key
```

##### 检查正在运行的节点
```Bash
# kubectl get nodes

NAME       STATUS   ROLES    AGE   VERSION
minikube   Ready    master   11m   v1.16.2
```

##### 检查Minikube的状态
```Bash
# minikube status
host: Running
kubelet: Running
apiserver: Running
kubeconfig: Configured
```

#### 列出所有minikube插件
```Bash
# minikube addons list

- addon-manager: enabled
- dashboard: enabled
- default-storageclass: enabled
- efk: disabled
- freshpod: disabled
- gvisor: disabled
- heapster: disabled
- helm-tiller: disabled
- ingress: disabled
- ingress-dns: disabled
- logviewer: disabled
- metrics-server: disabled
- nvidia-driver-installer: disabled
- nvidia-gpu-device-plugin: disabled
- registry: disabled
- registry-creds: disabled
- storage-provisioner: enabled
- storage-provisioner-gluster: disabled
```


---------------------------
#### 快速安装脚本
```Bash
curl -sL https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter01/kubernetes-install-ubuntu.sh | bash
```

> 到这里,一个单机版的`Kubernetes`集群环境已经安装启动完成了

-----------------------------------
更多学习文章在[点击访问](https://github.com/charSLee013/Kubernetes-learn)