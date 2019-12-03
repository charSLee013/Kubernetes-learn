### K8S学习指南(四)---用kubeadm方式搭建混合云集群k8s
> 网络上很多教程都是在本地用VM搭建多个虚拟机模拟集群.
> 本文根据实际服务器通过公网访问方式搭建混合云

------------------------------------
### 部署环境

| OS | CPU | RAM | LocaoIP | PublicIP | NOTE
| ------ | ------ | ------ | ------ | ------ | ------ |
| CentOS Linux release 7.6 | 1 | 2Gi | 10.16.0.8 | 193.112.189.xx| master |
| CentOS Linux release 7.3 | 1 | 2Gi | 172.16.63.255 | 112.74.59.xx | node1 |
| CentOS Linux release 7.6 | 1 | 2Gi | 192.168.0.75 | 121.36.21.xx | node2 |


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

##### 要求iptables不对bridge的数据进行处理
```Bash
sudo cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl --system
```

##### 关闭`swap`(可选,如果不关闭后面部署的时候要忽略swap错误)
```Bash
sudo swapoff -a
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
sudo systemctl enable kubelet && systemctl start kubelet
```



-------------------------------
#### 集群搭建
> 
##### 在`Master`机器上创建配置文件`kubeadm-init.yaml`
```Bash
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
  podSubnet: 192.168.0.0/16
scheduler: {}
EOF
```

以上配置文件中的`IPADDRESS`作为占位符,可以通过以下命令替换成**公网IP**

```Bash
ip=$(curl -s -4 ip.sb)
sed -i "s/IPADDRESS/$ip/g" kubeadm-init.yaml
```

##### 逐步安装`K8S`组件

```Bash
kubeadm init phase certs all --config kubeadm-init.yaml      
kubeadm init phase kubeconfig all --config kubeadm-init.yaml 
kubeadm init phase kubelet-start --config kubeadm-init.yaml    
kubeadm init phase control-plane all --config kubeadm-init.yaml  
kubeadm init phase etcd local --config kubeadm-init.yaml 
```

现在大部分服务器的网卡都是绑定`VPC`网卡而不是`公网IP`,到这一步如果继续创建的时候会出现访问超时的错误
这里要修改 `/etc/kubernetes/manifests/etcd.yaml`
```Bash
#把--listen-client-urls 和 --listen-peer-urls 都改成0.0.0.0：xxx

sed -i 's/--listen-client-urls=.*/--listen-client-urls=https:\/\/0.0.0.0:2379/g' /etc/kubernetes/manifests/etcd.yaml

sed -i 's/--listen-peer-urls=.*/--listen-peer-urls=https:\/\/0.0.0.0:2380/g' /etc/kubernetes/manifests/etcd.yaml
```

继续安装完成剩下的步骤

```Bash
## 这里忽略swap,cpu数量不足的错误
## 如果你关闭swap,cpu >=2 则可以取消忽略错误
kubeadm init --skip-phases=preflight,certs,kubeconfig,kubelet-start,control-plane,etcd --config kubeadm-init.yaml --ignore-preflight-errors=Swap  --ignore-preflight-errors=NumCPU 

```

**输出**

```Bash
[init] Using Kubernetes version: v1.16.0
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 10m0s
[apiclient] All control plane components are healthy after 0.014275 seconds
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
[kubelet] Creating a ConfigMap "kubelet-config-1.16" in namespace kube-system with the configuration for the kubelets in the cluster
[upload-certs] Skipping phase. Please see --upload-certs
[mark-control-plane] Marking the node master001 as control-plane by adding the label "node-role.kubernetes.io/master=''"
[mark-control-plane] Marking the node master001 as control-plane by adding the taints [node-role.kubernetes.io/master:NoSchedule]
[bootstrap-token] Using token: abcdef.66wcf1rc5wk6637f
[bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
[bootstrap-token] configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join <MASTER_IP>:6443 --token abcdef.66wcf1rc5wk6637f \
    --discovery-token-ca-cert-hash sha256:<YOUR_TOKEN>
```

继续完成命令
```Bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

记录下`kubeadm join` 命令,等下在`node`机器上用这条命令


##### 安装`Pod`网络插件
这里用的是`flannel`.
```Bash
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter04/kube-flannel.yml
```

##### 确保所有的Pod都处于Running状态
```Bash
kubectl get pod --all-namespaces -o wide
```

输出

```
NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE    IP             NODE              NOMINATED NODE   READINESS GATES
kube-system   calico-kube-controllers-6b64bcd855-jz8m6   1/1     Running   0          2m3s   192.168.1.66   master001   <none>           <none>
kube-system   calico-node-bv7jt                          1/1     Running   0          2m4s   10.16.0.8      master001   <none>           <none>
kube-system   coredns-58cc8c89f4-kts7t                   1/1     Running   0          22m    192.168.1.65   master001   <none>           <none>
kube-system   coredns-58cc8c89f4-z9bjv                   1/1     Running   0          22m    192.168.1.67   master001   <none>           <none>
kube-system   etcd-master001                       1/1     Running   0          21m    10.16.0.8      master001   <none>           <none>
kube-system   kube-apiserver-master001             1/1     Running   0          21m    10.16.0.8      master001   <none>           <none>
kube-system   kube-controller-manager-master001    1/1     Running   0          21m    10.16.0.8      master001   <none>           <none>
kube-system   kube-proxy-2t59q                           1/1     Running   0          22m    10.16.0.8      master001   <none>           <none>
kube-system   kube-scheduler-master001             1/1     Running   0          21m    10.16.0.8      master001   <none>           <none>
```

##### 如果想让`master`也参与工作负载(可选)
> 使用kubeadm初始化的集群，出于安全考虑Pod不会被调度到Master Node上，也就是说Master Node一般不参与工作负载

```Bash
# kubectl taint nodes master001 node-role.kubernetes.io/master-
node/master001 untainted
```

如果重复`kubeadm init`要先`kubeadm reset` 重新初始化一次

------------------------------

#### 向Kubernetes集群添加Node
> 添加节点前要安装完成 Docker,kubelet kubeadm kubectl 等

##### 添加命令
```Bash
kubeadm join --token <token> <master-ip>:<master-port> --discovery-token-ca-cert-hash sha256:<hash> \
## 自定义node名称,否则用hostname
--node-name=xxxxx
```

##### 查看`node节点`
```bash
## master 机器
kubectl get nodes
```

##### 查看token的值，在master节点运行以下命令
> 如果没有token，请使用命令kubeadm token create 创建

```Bash
kubeadm token list
```

##### 查看hash值，在master节点运行以下命令
```Bash
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
   openssl dgst -sha256 -hex | sed 's/^.* //'
```


---------------------------------------------
##### 其他
##### 移除节点
在`master` 上执行

```Bash
kubectl drain node1 --delete-local-data --force --ignore-daemonsets
kubectl delete node <node name>
```

在`node`上执行
```Bash
kubeadm reset
```

##### 测试DNS
在`master`上执行
```Bash
kubectl run curl --image=radial/busyboxplus:curl -it
```

输出

```Bash
kubectl run --generator=deployment/apps.v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
If you don't see a command prompt, try pressing enter.
[ root@curl-69c656fd45-nq2j2:/ ]$
```

然后再执行

```Bash
[ root@curl-69c656fd45-nq2j2:/ ]$ nslookup kubearntes.default
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

nslookup: can't resolve 'kubearntes.default'

##退出
exit
```

-----------------------------------
#### 一键部署命令
`Master`机器上执行
```Bash
## 安装
curl -sSL https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter04/kubernetes-centos-install.sh | bash

## 部署
curl -sSL https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter04/kubeam-init-master.sh | bash
```

`Node`机器上执行
```Bash
## 安装
curl -sSL https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter04/kubernetes-centos-install.sh | bash

## 从master复制join命令
kubeadm join --token <token> <master-ip>:<master-port> --discovery-token-ca-cert-hash sha256:<hash> \
## 自定义node名称,否则用hostname
--node-name=xxxxx
```

-----------------------------------
更多学习文章在[点击访问](https://github.com/charSLee013/Kubernetes-learn)