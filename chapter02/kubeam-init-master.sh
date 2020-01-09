#!/bin/bash

## add kubeadm-init.yaml
cat <<EOF > kubeadm-init.yaml
apiVersion: kubeadm.k8s.io/v1beta2
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.66wcf1rc5wk6637f            ## token 建议重新生成别用默认的
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "IPADDRESS"     # 内网IP地址
  bindPort: 6443            # API 端口
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: master001
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiServer:
  extraArgs: 
    advertise-address: "IPADDRESS"    ## 机器互联需要
  certSANs:
  - "IPADDRESS"
  timeoutForControlPlane: 10m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: gcr.azk8s.cn/google_containers       # image的仓库源,这里使用Azure的镜像
kind: ClusterConfiguration
kubernetesVersion: v1.17.0    ## 版本号一定要对上,截止笔者目前时间最新版已经是 1.17.0 了
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
  podSubnet: 192.168.0.0/24   ## 部署Calico的Pod网络段
scheduler: {}
EOF

## get local ip
ip=$(ifconfig eth0 | grep "inet" | awk '{print $2}')
sed -i "s/IPADDRESS/$ip/g" kubeadm-init.yaml

## command
echo "y" | kubeadm reset

## ignore cpus
kubeadm init --config kubeadm-init.yaml --ignore-preflight-errors=NumCPU

## use k8s
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


## install calico
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter02/calico.yaml

## add work for mater
# kubectl taint nodes master001 node-role.kubernetes.io/master-