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
  advertiseAddress: "IPADDRESS"     # 公网IP地址
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
    advertise-address: "IPADDRESS"    ## 公网机器互联需要
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
imageRepository: gcr.azk8s.cn/google_containers       # image的仓库源
kind: ClusterConfiguration
kubernetesVersion: v1.16.0
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
  podSubnet: 10.244.0.0/16
scheduler: {}
EOF
## get extranet ip
ip=$(curl -s -4 ip.sb)
sed -i "s/IPADDRESS/$ip/g" kubeadm-init.yaml

## command
echo "y" | kubeadm reset
# ignore swap cpus
kubeadm init phase certs all --config kubeadm-init.yaml      
kubeadm init phase kubeconfig all --config kubeadm-init.yaml 
kubeadm init phase kubelet-start --config kubeadm-init.yaml    
kubeadm init phase control-plane all --config kubeadm-init.yaml  
kubeadm init phase etcd local --config kubeadm-init.yaml 

## charge etcd.yaml
#把--listen-client-urls 和 --listen-peer-urls 都改成0.0.0.0：xxx
sed -i 's/--listen-client-urls=.*/--listen-client-urls=https:\/\/0.0.0.0:2379/g' /etc/kubernetes/manifests/etcd.yaml
sed -i 's/--listen-peer-urls=.*/--listen-peer-urls=https:\/\/0.0.0.0:2380/g' /etc/kubernetes/manifests/etcd.yaml

## init
kubeadm init --skip-phases=preflight,certs,kubeconfig,kubelet-start,control-plane,etcd --config kubeadm-init.yaml --ignore-preflight-errors=Swap  --ignore-preflight-errors=NumCPU


## use k8s
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config


## install flannel
<<<<<<< HEAD
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
=======
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter04/kube-flannel.yml
>>>>>>> 7e1804786a79203e71b7bc344f293078615aac69

## add work for mater
kubectl taint nodes master001 node-role.kubernetes.io/master-