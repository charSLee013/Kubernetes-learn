#!/bin/bash

## close firewall
sudo systemctl stop firewalld
sudo systemctl disable firewalld

## disblabe selinux
sudo setenforce 0
sudo sed "s/SELINUX=*/SELINUX=disabled/g" -i /etc/selinux/config

## open net bridge
sudo cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system

## close swap
sudo swapoff -a


## install docker.18.06.3 for aliyun.com
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
sudo yum makecache fast
sudo yum -y --setopt=obsoletes=0 install docker-ce-18.06.3.ce-3.el7 \
docker-ce-selinux-18.06.3.ce-3.el7 

## docker hub for azk8s
cat <<EOF > /etc/docker/daemon.json
{
  "registry-mirrors": [
    "https://dockerhub.azk8s.cn",
    "https://hub-mirror.c.163.com"
  ]
}
EOF

## start docker
sudo systemctl enable docker && systemctl start docker

############################################################

## add k8s repo
sudo cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

## install kuberetes
sudo yum install -y kubelet kubeadm kubectl
sudo systemctl enable kubelet && systemctl start kubelet