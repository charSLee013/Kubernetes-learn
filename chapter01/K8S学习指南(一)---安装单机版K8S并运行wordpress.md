### K8S学习指南(一)---安装单机版K8S并运行wordpress

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

> 机器建议使用能连接上谷歌的,因为K8S很多包和源都在海外.

#### 搭建步骤

**快速安装脚本**
```Bash
curl -sL https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/kubernetes-install.sh | bash
```

1. 关闭防火墙
```Bash
systemctl disable firewalld
systemctl stop firewalld
```

2. 安装`etcd`和`Kubernetes`软件(会自动安装`Docker`)
```Bash
yum update -y && yum install -y etcd kubernetes
# 这里安装的是redhat7的证书.因为Kubernetes默认会去redhat拉去镜像.但是没有证书会报Error,所以先下载好证书
wget http://mirror.centos.org/centos/7/os/x86_64/Packages/python-rhsm-certificates-1.19.10-1.el7_4.x86_64.rpm
rpm2cpio python-rhsm-certificates-1.19.10-1.el7_4.x86_64.rpm | cpio -iv --to-stdout ./etc/rhsm/ca/redhat-uep.pem | tee /etc/rhsm/ca/redhat-uep.pem
```

3. 按顺序启动所有的服务:
```Bash
systemctl restart etcd
systemctl restart docker
systemctl restart kube-apiserver
systemctl restart kube-controller-manager
systemctl restart kube-scheduler
systemctl restart kubelet
systemctl restart kube-proxy
```


> 到这里,一个单机版的`Kubernetes`集群环境已经安装启动完成了


--------------------------------------------
### 启动`Mysql`服务
1. 首先为`Mysql`服务创建一个`RC`定义文件 `mysql-rc.yaml`

<details>
<summary>Replication Controlle</summary>
Replication Controller（RC）是Kubernetes中的另一个核心概念，应用托管在Kubernetes之后，Kubernetes需要保证应用能够持续运行，这是RC的工作内容，它会确保任何时间Kubernetes中都有指定数量的Pod在运行。在此基础上，RC还提供了一些更高级的特性，比如滚动升级、升级回滚.

Deployment 和 Replica Set是官方推荐的另一个方法用来替代RC.


Deployment为Pod和ReplicaSet提供了一个声明式定义(declarative)方法，用来替代以前的ReplicationController来方便的管理应用。典型的应用场景包括
- 定义Deployment来创建Pod和ReplicaSet
- 滚动升级和回滚应用
- 扩容和缩容
- 暂停和继续Deployment
</details>


* 模版可以参考[rc.yaml](https://raw.githubusercontent.com/openshift-evangelists/kbe/master/specs/rcs/rc.yaml)
```yaml
apiVersion: v1  #指定api版本，此值必须在kubectl apiversion中
kind: ReplicationController # 指定创建资源的角色/类型.这里定义的是这是一个RC文件.
metadata:       # 源的元数据/属性
  name: mysql    # RC的名称,全局唯一
spec:           # RC的相关属性定义.
  replicas: 1   # Pod 副本数量.如果实例数量少于此,则K8S则会根据RC文件中定义的Pod模板创建一个新的Pod调度到合适的Node上
  selector:     # K8S通过spec.selector来筛选要控制的Pod 
    app: mysql
  template:     # 这里定义Pod模版.K8S会根据此模板创建实例(副本)
    metadata:
      labels:
        app: mysql  # Pod 副本拥有的标签,对应 RC 的 selector.这里的labels必须匹配之前的spec.selector,否则创建一个无法匹配的Pod就会不停尝试创建新的Pod
    spec:
      containers:   # 容器内定义部分
      - name: mysql
        image: mysql:5.6        # 对应的Docker Image.
        ports:
        - containerPort: 3306   # 容器开发对外的端口
        env:                    # 指定容器中的环境变量
        - name: MYSQL_ROOT_PASSWORD     # 自定义root密码
          value: "123456"
```

2. 创建好 `mysql-rc.yaml` 文件后,将他发布到`K8S`集群中,我们需要在`Master`节点中执行命令:
```Bash
# kubectl create -f mysql-rc.yaml 
replicationcontroller "mysql" created
```

3. 用 `kubectl` 命令查看刚刚创建的RC
```Bash# kubectl get rc
NAME      DESIRED   CURRENT   READY     AGE
mysql
     1         0         0         45s
```
4. 查看`Pod`的创建情况时,可以运行下面的命令
> kubectl describe pod 可以查看更加详细的情况
```Bash
# kubectl get pods -o wide --all-namespaces
NAMESPACE   NAME          READY     STATUS              RESTARTS   AGE       IP        NODE
default     mysql-8mr4x   0/1       ContainerCreating   0          28s       <none>    127.0.0.1


## 如果执行kubectl create -f mysql-rc.yaml，反馈正常
## 执行kubectl get pods，显示no resources found
## 解决方法:配置文件在/etc/kubernetes/apiserver，把--admission_control参数中的ServiceAccount删除
sed -i "s/ServiceAccount,//g" /etc/kubernetes/apiserver
# 重启一下
systemctl restart kube-apiserver
```

> 我们看到一个名为 `mysql-xxxx` 的`Pod`实例,这是K8S根据`mysql` 这个RC的定义自动创建的`Pod`.

> 由于`Pod`的调度以及下载`Docker Image`都需要一段时间,当`Pod`成功创建容器以后,状态会更新为`Running`.

5. 通过`docker ps` 查看正在运行的容器.发现除了`Mysql`服务的`Pod`容器以及创建了,此外还有一个`k8s_POD`的`Pause`容器.这就是`Pod`的"根服务器".

```
# docker ps
CONTAINER ID        IMAGE                                                        COMMAND                  CREATED             STATUS              PORTS               NAMES
c843d27db307        mysql:5.7                                                    "docker-entrypoint..."   16 minutes ago      Up 16 minutes                           k8s_mysql.68c31e77_mysql-8mr4x_default_f7355bfd-06c8-11ea-9e3d-00163e06ee40_2fdd39e7
8e2b85f8ef30        registry.access.redhat.com/rhel7/pod-infrastructure:latest   "/usr/bin/pod"           16 minutes ago      Up 16 minutes                           k8s_POD.1d520ba5_mysql-8mr4x_default_f7355bfd-06c8-11ea-9e3d-00163e06ee40_478b45fb
```

6. 最后需要创建一个与之关联的 `Kubernetes Service`--Mysql的定义文件 `mysql-svc.yaml`

<details>
<summary>Kubernetes Service</summary>
虽然每个Pod都会分配一个单独的IP地址，但这个IP地址会随着Pod的销毁而消失。这就引出一个问题：如果有一组Pod组成的一个集群来提供服务，那么如何来访问它们呢?
Kubernetes的Service（服务）就是用来解决这个问题的核心概念.
一个Service可以看作一组提供相同服务的Pod的对外访问接口。Service作用于哪些Pod是通过Label Selector来定义的.
比如运行了3个`Web Server` 的副本,这两个`Pod`对于前端来说没有任何区别,所以前端不关心是哪个`Web Server`提供服务.而且如果`Web Server`出了变化比如某个`Node`挂了,Pod会在另一个`Node`重新生成,而作为前端无须跟踪这些变化 "Service" 就是用来实现这种解耦的抽象概念.
</details>

* 模版可以参考[svc.yaml](https://raw.githubusercontent.com/openshift-evangelists/kbe/master/specs/services/svc.yaml)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql       ## 定义Service的服务名.
  labels: 
    app: mysql  ## 归属于 myweb
spec:
  ports:
    - port: 3306    ## port属性定义了Service的虚拟端口.
  selector:         ## 确定了哪些Pod副本对应到本服务
    app: mysql
```

7. 运行`Kubectl`命令创建`Service`

```Bash
# kubectl create -f mysql-svc.yaml
service "mysql" created
```


8. 查看刚刚创建的`Service`

```Bash
# kubectl get svc
NAME         CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kubernetes   10.254.0.1      <none>        443/TCP    2m
mysql        10.254.38.220   <none>        3306/TCP   4s
```
> 注意到`Mysql`服务被分配到一个值为`10.254.38.220`的`Cluster IP`地址,这是一个虚拟地址

> Kubernetes 集群中其他新创建的`Pod`就可以通过`Service`的`Cluster IP`+端口号 3306来连接和访问


--------------------------------------------
### 启动`myweb` 博客
上面已经定义和创建好`Mysql`服务.接下来完成`myweb`应用的启动过程
1. 首先创建对应的RC文件`myweb-rc.yaml`
```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: myweb
spec:
  replicas: 2
  selector:
    app: myweb
  template:
    metadata:
      labels:
        app: myweb
    spec:
      containers:
      - name: myweb
        image: kubeguide/tomcat-app:v1
        ports:
        - containerPort: 8080
```

2. 创建对应的`Service`文件`myweb-svc.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myweb
spec:
  type: NodePort        ## 开启Node外网访问模式
  ports:
    - port: 8080
      nodePort: 30001   ## Kubernetes 允许外网端口范围是 30000-32767.
  selector:
    app: myweb
```

3. 创建`myweb`的`RC`和`Service`
```
# kubectl create -f myweb-rc.yaml
replicationcontroller "myweb" created

# kubectl create -f myweb-svc.yaml 
service "myweb" created
```

4. 查看创建的`myweb`
```
# kubectl get pod
NAME              READY     STATUS    RESTARTS   AGE
mysql-8mr4x       1/1       Running   0          2h
myweb-8vq6v   1/1       Running   0          1h
myweb-n4121   1/1       Running   0          1h
# kubectl get svc
NAME         CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kubernetes   10.254.0.1      <none>        443/TCP        5h
mysql        10.254.95.12    <none>        3306/TCP       1h
myweb    10.254.171.40   <nodes>       80:30001/TCP   20s
```

5. 在浏览器上输入 `http://Node的IP:30001/` 或者 curl `http://Node的IP:30001/`


--------------------------------------------
### 其他

<details>
<summary>Kubernetes 删除</summary>

```Bash
kubectl delete ([-f FILENAME] | TYPE [(NAME | -l label | --all)])
```

**示例**
```Bash
# 通过pod.json文件中指定的资源类型和名称删除一个pod
$ kubectl delete -f ./mysql-rc.yaml

# 通过控制台输入的JSON所指定的资源类型和名称删除一个pod
$ cat pod.json | kubectl delete -f -

# 删除所有名为“baz”和“foo”的pod和service
$ kubectl delete pod,service baz foo

# 删除所有带有lable name=myLabel的pod和service
$ kubectl delete pods,services -l name=myLabel

# 删除UID为1234-56-7890-234234-456456的pod
$ kubectl delete pod 1234-56-7890-234234-456456

# 删除所有的pod
$ kubectl delete pods --all
```

**选项**
```Bash
      --all[=false]: 使用[-all]选择所有指定的资源。
      --cascade[=true]: 如果为true，级联删除指定资源所管理的其他资源（例如：被replication controller管理的所有pod）。默认为true。
  -f, --filename=[]: 用以指定待删除资源的文件名，目录名或者URL。
      --grace-period=-1: 安全删除资源前等待的秒数。如果为负值则忽略该选项。
      --ignore-not-found[=false]: 当待删除资源未找到时，也认为删除成功。如果设置了--all选项，则默认为true。
  -o, --output="": 输出格式，使用“-o name”来输出简短格式（资源类型/资源名）。
  -l, --selector="": 用于过滤资源的Label。
      --timeout=0: 删除资源的超时设置，0表示根据待删除资源的大小由系统决定。
```

**继承自父命令的选项**
```Bash
      --alsologtostderr[=false]: 同时输出日志到标准错误控制台和文件。
      --api-version="": 和服务端交互使用的API版本。
      --certificate-authority="": 用以进行认证授权的.cert文件路径。
      --client-certificate="": TLS使用的客户端证书路径。
      --client-key="": TLS使用的客户端密钥路径。
      --cluster="": 指定使用的kubeconfig配置文件中的集群名。
      --context="": 指定使用的kubeconfig配置文件中的环境名。
      --insecure-skip-tls-verify[=false]: 如果为true，将不会检查服务器凭证的有效性，这会导致你的HTTPS链接变得不安全。
      --kubeconfig="": 命令行请求使用的配置文件路径。
      --log-backtrace-at=:0: 当日志长度超过定义的行数时，忽略堆栈信息。
      --log-dir="": 如果不为空，将日志文件写入此目录。
      --log-flush-frequency=5s: 刷新日志的最大时间间隔。
      --logtostderr[=true]: 输出日志到标准错误控制台，不输出到文件。
      --match-server-version[=false]: 要求服务端和客户端版本匹配。
      --namespace="": 如果不为空，命令将使用此namespace。
      --password="": API Server进行简单认证使用的密码。
  -s, --server="": Kubernetes API Server的地址和端口号。
      --stderrthreshold=2: 高于此级别的日志将被输出到错误控制台。
      --token="": 认证到API Server使用的令牌。
      --user="": 指定使用的kubeconfig配置文件中的用户名。
      --username="": API Server进行简单认证使用的用户名。
      --v=0: 指定输出日志的级别。
      --vmodule=: 指定输出日志的模块，格式如下：pattern=N，使用逗号分隔。
```
</details>

<!-- 

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: myweb
spec:
  replicas: 2
  selector:
    app: myweb
  template:
    metadata:
      labels:
        app: myweb
    spec:
      containers:
      - name: mysql
        image: kubeguide/tomcat-app:v1
        ports:
        - containerPort: 8080
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myweb
spec:
  type: NodePort
  ports:
    - port: 8080
      nodePort: 30001
  selector:
    app: myweb
```


kubectl delete pv,pvc,pod,rc,pods,svc,secrets --all
-->