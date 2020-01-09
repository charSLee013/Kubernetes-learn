### Kubernetes学习指南(一)--快速部署集群

##### `Kubernetes` 概述

> `Kubernetes`(以下简称K8S) 是一个完备的分布式系统支撑平台。包含安全防护，负载均衡，多粒度的资源配额管理能力.
> 
> 
 以下介绍K8S组成部分

------------------------

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
    * OS: CentOS Linux release 7 +
    * USER: root (生产环境中禁止使用`root`)
    * CPU: 1+   (如果CPUNumber 小于 2 时 ,`kubeadm init`需要添加` --ignore-preflight-errors=NumCPU` 选项
    * RAM: 2Gib+

#### 机器准备

| OS | CPU | RAM | LocaoIP | NOTE |
| :------ | :------ | :------ | :------ | :------ |
| CentOS Linux release 7.3 | 1 | 2Gib | 172.17.50.23 | master |
| CentOS Linux release 7.3 | 1 | 2Gib | 172.17.50.24 | node1 |
| CentOS Linux release 7.3 | 1 | 2Gib | 172.17.50.25 | node2 |


------------------------------------

### 部署步骤

##### 关闭防火墙

```Bash
sudo systemctl stop firewalld
sudo systemctl disable firewalld
```

##### 关闭`SELINUX`

```Bash
## 临时关闭
sudo setenforce 0
## 永久关闭
sudo sed "s/SELINUX=*/SELINUX=disabled/g" -i /etc/selinux/config
```

##### 关闭`swap`

```Bash
sudo swapoff -a
```

##### 设置iptables不对bridge的数据进行处理

```Bash
sudo cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
```

##### 安装`Docker`(v18.06.3)

```Bash
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

## 修改为阿里云源
sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
sudo yum makecache fast
sudo yum -y --setopt=obsoletes=0 install docker-ce-18.06.3.ce-3.el7 \
docker-ce-selinux-18.06.3.ce-3.el7 

## 现在开启和设置开机自自动
sudo systemctl enable docker && systemctl start docker
```

##### 添加`K8S`源

```Bash
## 默认源是google,这里修改为阿里源
sudo cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```

##### 安装`kubelet` `kubeadm` `kubectl`

```Bash
sudo yum install -y kubelet kubeadm kubectl

## 设置开机自启动
sudo systemctl enable kubelet && systemctl start kubelet
```

#### 检查`Kubernetes` 版本

```Bash
# kubectl version

Client Version: version.Info{Major:"1", Minor:"17", GitVersion:"v1.17.0", GitCommit:"70132b0f130acc0bed193d9ba59dd186f0e634cf", GitTreeState:"clean", BuildDate:"2019-12-07T21:20:10Z", GoVersion:"go1.13.4", Compiler:"gc", Platform:"linux/amd64"}
```

至此,`master`主机上的`Kubernetes`已经安装完成了,剩下把其他的`Node`机器按照步骤安装

或者使用下面**一键安装命令**一键部署

-----------------------------------

#### 一键安装命令

```Bash
curl -sSL https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter01/kubernetes-centos-install.sh | bash
```
-----------------------------------

**注意事项** 
* 一键安装命令会把`yum`源改成`Aliyun`
* 根据`Pod Network`选择的不同,有些组件可能需要开启`iptables`转发功能(详情请参考组件官网)

-----------------------------------
更多学习文章在[点击访问](https://github.com/charSLee013/Kubernetes-learn)