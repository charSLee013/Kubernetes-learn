### Kubernetes学习指南(二)--使用Kubeadm搭建集群

>上一篇文章已经在各个机器安装好`Kubernetes`,接下来首先在`Master`机器搭建`Master`

-------------------------------
#### 集群搭建

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
```

以上配置文件中的`IPADDRESS`作为占位符,可以通过以下命令替换成**内网IP** (默认读取`eth0`网卡的信息,手动指定请改写)

```Bash
ip=$(ifconfig eth0 | grep "inet" | awk '{print $2}')
sed -i "s/IPADDRESS/$ip/g" kubeadm-init.yaml
```

##### 开始部署

```Bash
## 这里忽略swap,cpu数量不足的错误
## 如果你关闭swap,cpu >=2 则可以取消忽略错误
kubeadm init --config kubeadm-init.yaml --ignore-preflight-errors=NumCPU 
```

如果重复`kubeadm init`要先`kubeadm reset` 重新初始化一次

**输出**

```Bash
# kubeadm init --config kubeadm-init.yaml --ignore-preflight-errors=NumCPU

W0109 08:51:56.532812    3195 validation.go:28] Cannot validate kube-proxy config - no validator is available
W0109 08:51:56.532880    3195 validation.go:28] Cannot validate kubelet config - no validator is available
[init] Using Kubernetes version: v1.17.0

###略略略

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.17.50.23:6443 --token abcdef.66wcf1rc5wk6637f \
    --discovery-token-ca-cert-hash sha256:201961c9ccd44987f265b1a3d84de663332b50d0ecd2677a5b2be025416d1cea
```

继续完成命令

```Bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

记录下`kubeadm join` 命令,等下在`node`机器上用这条命令


##### 安装`Calico`网络插件

```Bash
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter02/calico.yaml
```

>原文件地址在`https://docs.projectcalico.org/v3.11/manifests/calico.yaml`
源文件`podSubnet`是`192.168.0.0/16` 
这里修改为`192.168.0.0/24`

##### 确保所有的Pod都处于Running状态

```Bash
kubectl get pod --all-namespaces -o wide
```

输出

```
NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE     IP             NODE        NOMINATED NODE   READINESS GATES
kube-system   calico-kube-controllers-648f4868b8-wmdlz   1/1     Running   0          69s     192.168.0.1    master001   <none>           <none>
kube-system   calico-node-lmkhv                          1/1     Running   0          70s     172.17.50.23   master001   <none>           <none>
kube-system   coredns-6cd559f5d5-2h4pb                   1/1     Running   0          2m38s   192.168.0.3    master001   <none>           <none>
kube-system   coredns-6cd559f5d5-6zl68                   1/1     Running   0          2m38s   192.168.0.2    master001   <none>           <none>
kube-system   etcd-master001                             1/1     Running   0          2m51s   172.17.50.23   master001   <none>           <none>
kube-system   kube-apiserver-master001                   1/1     Running   0          2m51s   172.17.50.23   master001   <none>           <none>
kube-system   kube-controller-manager-master001          1/1     Running   0          2m51s   172.17.50.23   master001   <none>           <none>
kube-system   kube-proxy-5kfjh                           1/1     Running   0          2m38s   172.17.50.23   master001   <none>           <none>
kube-system   kube-scheduler-master001                   1/1     Running   0          2m51s   172.17.50.23   master001   <none>           <none>
```


##### 如果想让`master`也参与工作负载(可选)
> 使用kubeadm初始化的集群，出于安全考虑Pod不会被调度到Master Node上，也就是说Master Node不推荐参与工作负载

```Bash
# kubectl taint nodes master001 node-role.kubernetes.io/master-
node/master001 untainted
```

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
# kubectl get nodes

NAME        STATUS     ROLES    AGE   VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION               CONTAINER-RUNTIME
master001   Ready      master   11m   v1.17.0   172.17.50.23   <none>        CentOS Linux 7 (Core)   3.10.0-514.26.2.el7.x86_64   docker://18.6.3
node1       Ready      <none>   56s   v1.17.0   172.17.50.24   <none>        CentOS Linux 7 (Core)   3.10.0-514.26.2.el7.x86_64   docker://18.6.3
node2       NotReady   <none>   22s   v1.17.0   172.17.50.25   <none>        CentOS Linux 7 (Core)   3.10.0-514.26.2.el7.x86_64   docker://18.6.3
```

##### 查看token的值，在master节点运行以下命令
> 如果没有token，请使用命令kubeadm token create 创建

```Bash
# kubeadm token list

TOKEN                     TTL         EXPIRES                     USAGES                   DESCRIPTION                                                EXTRA GROUPS
<YOUR_TOKEN>  23h         2020-01-10T09:10:05+08:00   authentication,signing   <none>                                                     system:bootstrappers:kubeadm:default-node-token
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
# kubectl run curl --image=radial/busyboxplus:curl -it

kubectl run --generator=deployment/apps.v1 is DEPRECATED and will be removed in a future version. Use kubectl run --generator=run-pod/v1 or kubectl create instead.
If you don't see a command prompt, try pressing enter.
[ root@curl-69c656fd45-pg4pn:/ ]$
```

然后再执行

```Bash
[ root@curl-69c656fd45-pg4pn:/ ]$ nslookup kubearntes.default
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
## 如果没有安装可以执行下面命令安装
curl -sSL https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter01/kubernetes-centos-install.sh | bash

## 部署
curl -sSL https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter02/kubeam-init-master.sh | bash
```

`Node`机器上执行

```Bash
## 如果没有安装可以执行下面命令安装
curl -sSL https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter01/kubernetes-centos-install.sh | bash

## 从master复制join命令
kubeadm join --token <token> <master-ip>:<master-port> --discovery-token-ca-cert-hash sha256:<hash> \
## 自定义node名称,否则用hostname
--node-name=xxxxx
```

-----------------------------------
更多学习文章在[点击访问](https://github.com/charSLee013/Kubernetes-learn)