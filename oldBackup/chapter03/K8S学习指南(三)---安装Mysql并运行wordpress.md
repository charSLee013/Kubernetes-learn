### K8S学习指南(三)---安装Mysql并运行wordpress

--------------------------------------------
#### 创建`Mysql`服务
定义一个服务需要三部分`Pod` `Service` `PV(PVC)`
```yaml
# mysql-deployment.yaml 

apiVersion: v1            ## 指定APi版本
kind: Service             ## 表明是 kubernetes Service 
metadata:
  name: wordpress-mysql   ## Service 的全局唯一名称
  labels:
    app: wordpress        ## 用来识别pod
spec:
  ports:
    - port: 3306          ## 这里是创建虚拟IP的端口,直接ping 和 curl 是不通的
  selector:               ## 选择 pod.metadata.app&tier == wordpress&mysql 的pod(是的,一个service是可以对接多个pod的)
    app: wordpress
    tier: mysql
  clusterIP: None         ## 不建立虚拟IP
---
apiVersion: v1
kind: PersistentVolumeClaim   ## 是用户存储的请求，PVC消耗PV的资源，可以请求特定的大小和访问模式，需要指定归属于某个Namespace，在同一个Namespace的Pod才可以指定对应的PVC
metadata:
  name: mysql-pv-claim
  labels:
    app: wordpress
spec:
  accessModes:
    - ReadWriteOnce          ## 该volume只能被单个节点以读写的方式映射
  resources:
    requests:
      storage: 8Gi
---
## 定义Pod
apiVersion: apps/v1 # for versions before 1.9.0 use apps/v1beta2
kind: Deployment          ## 指定创建资源的角色/类型.这里定义的是一个
metadata:
  name: wordpress-mysql   ## 全局唯一名称
  labels:
    app: wordpress
spec:                     ## 相关属性定义
  selector:               ## kubernetes 通过 spec.selector来筛选要控制的Pod
    matchLabels:
      app: wordpress
      tier: mysql
  strategy:               ## 指新的Pod替换旧的Pod的策略
    type: Recreate        ## Recreate  重建策略，在创建出新的Pod之前会先杀掉所有已存在的Pod
  template:               ## 这里定义Pod模版.K8S会根据此模板创建实例(副本)
    metadata:             ## # Pod 副本拥有的标签,对应 RC 的 selector.这里的labels必须匹配之前的spec.selector,否则创建一个无法匹配的Pod就会不停尝试创建新的Pod
      labels:
        app: wordpress
        tier: mysql
    spec:                 ## 容器内定义内容
      containers:
      - image: mysql:5.6  ## 对应Docker Image
        name: mysql
        env:
        - name: MYSQL_ROOT_PASSWORD   ## 定义root密码
          value: "123456"
        ports:
        - containerPort: 3306
          name: mysql
        volumeMounts:     ##  volumeMounts 字段保证了 /var/lib/mysql 文件夹由一个 PersistentVolume 支持
        - name: mysql-persistent-storage
          mountPath: /var/lib/mysql
      volumes:            ## 指定Volume的类型和内容
      - name: mysql-persistent-storage
        persistentVolumeClaim:
          claimName: mysql-pv-claim   ## 这里表明使用上文创建的PVC
```

1. 创建好 `mysql-deployment.yaml ` 文件后,将他发布到`K8S`集群中,我们需要在`Master`节点中执行命令:
```Bash
# kubectl create -f mysql-deployment.yaml

service/wordpress-mysql created
persistentvolumeclaim/mysql-pv-claim created
deployment.apps/wordpress-mysql created
```

2. 用 `kubectl` 命令查看刚刚创建的`Dem`
  
```Bash
# kubectl get deployment
NAME              READY   UP-TO-DATE   AVAILABLE   AGE
wordpress-mysql   1/1     1            1           89m
```

3. 查看刚刚创建的`Service`

```Bash
# kubectl get svc
NAME              TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
kubernetes        ClusterIP   10.96.0.1    <none>        443/TCP    139m
wordpress-mysql   ClusterIP   None         <none>        3306/TCP   90m
```

4. 查看`Pod`的创建情况时,可以运行下面的命令
> kubectl describe pod 可以查看更加详细的情况
```Bash
r# kubectl get pods -o wide --all-namespaces
NAMESPACE              NAME                                         READY   STATUS    RESTARTS   AGE    IP           NODE       NOMINATED NODE   READINESS GATES
default                wordpress-mysql-b67565868-pvlps              1/1     Running   0          90m    
```

<!-- ## 如果执行kubectl create -f mysql-rc.yaml，反馈正常
## 执行kubectl get pods，显示no resources found
## 解决方法:配置文件在/etc/kubernetes/apiserver，把--admission_control参数中的ServiceAccount删除
sed -i "s/ServiceAccount,//g" /etc/kubernetes/apiserver
# 重启一下
systemctl restart kube-apiserver -->


> 我们看到一个名为 `wordpress-mysql--xxxx` 的`Pod`实例,这是K8S根据`mysql` 这个RC的定义自动创建的`Pod`.

> 由于`Pod`的调度以及下载`Docker Image`都需要一段时间,当`Pod`成功创建容器以后,状态会更新为`Running`.

5. 通过`docker ps` 查看正在运行的容器.发现除了`Mysql`服务的`Pod`容器以及创建了,此外还有一个`k8s_POD`的`Pause`容器.这就是`Pod`的"根服务器".

```
# docker ps | grep mysql
1dae03a4fcdd        mysql                           "docker-entrypoint.s…"   2 hours ago         Up 2 hours                              k8s_mysql_wordpress-mysql-b67565868-pvlps_default_58f50096-fec0-43ed-ad01-4c696f155b58_0
37483feec714        k8s.gcr.io/pause:3.1            "/pause"                 2 hours ago         Up 2 hours                              k8s_POD_wordpress-mysql-b67565868-pvlps_default_58f50096-fec0-43ed-ad01-4c696f155b58_0

```

--------------------------------------------

### 启动`myweb` 博客
上面已经定义和创建好`Mysql`服务.接下来完成`wordpress`应用的启动过程
1. 首先创建对应的文件`wordpress-deployment.yaml`
```yaml
# application/wordpress/wordpress-deployment.yaml

apiVersion: v1
kind: Service
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  ports:
    - port: 80
  selector:
    app: wordpress
    tier: frontend
  type: LoadBalancer
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: wp-pv-claim
  labels:
    app: wordpress
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1 # for versions before 1.9.0 use apps/v1beta2
kind: Deployment
metadata:
  name: wordpress
  labels:
    app: wordpress
spec:
  selector:
    matchLabels:
      app: wordpress
      tier: frontend
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: wordpress
        tier: frontend
    spec:
      containers:
      - image: wordpress:4.8-apache
        name: wordpress
        env:
        - name: WORDPRESS_DB_HOST
          value: wordpress-mysql
        - name: WORDPRESS_DB_PASSWORD
          value: "123456"
        ports:
        - containerPort: 80
          name: wordpress
        volumeMounts:
        - name: wordpress-persistent-storage
          mountPath: /var/www/html
      volumes:
      - name: wordpress-persistent-storage
        persistentVolumeClaim:
          claimName: wp-pv-claim
```

2. 查看创建的`wordpress`对外开放端口

```Bash
#  kubectl get services wordpress
NAME        TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
wordpress   LoadBalancer   10.107.143.141   <pending>     80:32314/TCP   5m2
```
> 可以看到对外开放`NodePort`是 32314.(如果不指定随机在30000 - 350000中选取)

 在浏览器上输入 `http://Node的IP:32314/` 即可登陆`wordpress`

![avatar][wordpress]

--------------------------------------------
#### 快速安装
```Bash
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter03/mysql-deployment.yaml
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter03/wordpress-deployment.yaml
```
--------------------------------------------
### 其他

<details>
<summary>Kubernetes 删除资源指令</summary>

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

-----------------------------------
更多学习文章在[点击访问](https://github.com/charSLee013/Kubernetes-learn)

-----------------------------------
[wordpress]:data:image/png;base64,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PDLnUKLQGiVKPZaZE92Rkk8elW06/iTTi8dXcfa0E3r0/oOHV0qURuSROYcShdYoUepxUyUKrCgPxWtRonBxlCj1uJESBS6XEoWLo0SphxKFxilRuDhKlHooUWicEoWLo0SphxKFxilRuDhKlHooUWicEoWLo0SphxKFxilRuDhKlHooUWicEoWLo0SphxKFxilRuDhKlHooUWicEoWLo0SphxKFxilRuDhKlHooUWicEoWLo0SphxKFxilRuDhKlHooUWicEoWLo0SphxKFxilRuDhKlHooUWicEoWLo0SphxKFxilRuDhKlHooUWicEoWLo0SphxKFxilRuDhKlHooUWicEoWLo0SphxKFxilRuDhKlHooUSrzT37vP/6v7/rYnXd8tIUlvNLwevMrvy4lChdHiVIPJUpN/smH/93/8pN/cOcX//jO//WpJpZf/OPwesOrzq//WpQoXBwlSj2UKDX5n374/Xfe+8lprtW9vPeT4VXn138tShQujhKlHkqUmtz5p78+DbUWln/66/n1X4sShYujRKmHEqUmSvQalChcHCVKPZQoNVGi16BE4eIoUeqhRKmJEr0GJQoXR4lSDyVKTZToNShRuDhKlHooUWqiRK9BicLFUaLUQ4lSEyV6DUoULo4SpR5KlJoo0WtQonBxlCj1UKLUZHaJ/uIf33nPJzfLy9+cKezhvTexn1mLEoXGKFHqoUSpybwSDen57o/fuftbd37kQ90Sfvjpx3fe+0fTzY4uXX3GZ4Uffu7qzk985M5Pf/w6+7n2okShMUqUeihRajKjRH/hD7tk/P2vvJmfGvz9n37sQ3d+5t/Mm9EMxRmeEnYVGvQXXr/zjv/8hW996wuf+8js/bzMokShMUqUeihRanJqib7nD+/8+O+844t/39Xn77//zts/2C0f++oX/vOTbpY0zXFuX7L/xT/q1g8PhR/CQ//s39z5+Nfe/NabH/ixD9/52U90PfrjH7nzU3FOdHv7tJ/0UPo5/9ofYrPxnEv8ShQao0SphxKlJieVaCi8kJv//s1vhXx82wfuvOv3u7nMsPzMv85X1X821OTvxEv2v9Fdsg8bh5UhDcOWP/GR/qEP3bn/u113hv/bTay++YEfel/3aJofDU8JO9ze/hf+sFvCD+GhsMNwMulqfnhWOMTPv37n/u/d+dG4ceja0LgnxqgShcYo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