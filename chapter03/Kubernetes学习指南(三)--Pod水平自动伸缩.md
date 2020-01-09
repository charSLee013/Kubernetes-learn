### Kubernetes学习指南(三)--Pod水平自动伸缩

Pod 水平自动伸缩（Horizontal Pod Autoscaler）特性， 可以基于CPU利用率自动伸缩 replication controller、deployment和 replica set 中的 pod 数量，（除了 CPU 利用率）也可以 基于其他应程序提供的度量指标

-----------------------------------
### 安装指标收集组件`Metrics server`

#### 下载项目

```Bash
## 没有安装 git 要先安装
# yum install git -y

git clone https://github.com/kubernetes-sigs/metrics-server.git
```

#### 添加参数
>vim metrics-server/deploy/1.8+/metrics-server-deployment.yaml
```Bash
      containers:
      - name: metrics-server
        image: k8s.gcr.io/metrics-server-amd64:v0.3.6
## 添加下面几行
        command:
          - /metrics-server
          - --kubelet-insecure-tls
          - --kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS,ExternalDNS,ExternalIP
          - --v=2
```

#### 开始安装

```Bash
# kubectl apply -f metrics-server/deploy/1.8+/

clusterrole.rbac.authorization.k8s.io/system:aggregated-metrics-reader created
clusterrolebinding.rbac.authorization.k8s.io/metrics-server:system:auth-delegator created
rolebinding.rbac.authorization.k8s.io/metrics-server-auth-reader created
apiservice.apiregistration.k8s.io/v1beta1.metrics.k8s.io created
serviceaccount/metrics-server created
deployment.apps/metrics-server created
service/metrics-server created
clusterrole.rbac.authorization.k8s.io/system:metrics-server created
clusterrolebinding.rbac.authorization.k8s.io/system:metrics-server created
```

或者直接使用修改完成的版本

```Bash
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter03/metrics-server-1.8.yaml
```

#### 查看机器的负载情况

```Bash
#kubectl top node
NAME        CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
master001   131m         13%    1166Mi          67%
node1       78m          7%     922Mi           53%
node2       80m          8%     934Mi           53%
```

-----------------------------------
### 创建自动扩容和缩容`Pod`

下面通过为一个`Deployment`设置`HPA`,然后使用一个客户端为其进行压力测试,对`HPA`的用法进行实例

#### 以`php-apache`的`Deployment`为例,设置 `cpu request = 200m`,未设置 `limit` 上限的值

```Bash
cat  <<EOF > php-apache-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: php-apache
  template:
    metadata:
      name: php-apache
      labels:
        app: php-apache
    spec:
      containers:
        - image: k8s.gcr.io/hpa-example
          name: php-apache
          ports:
          - containerPort: 80
            protocol: TCP
          resources:
            requests:
              cpu: 200m
EOF

kubectl apply -f php-apache-deployment.yaml
```

再创建一个`php-apache`的`Service`,供客户端访问

```Bash
cat <<EOF >php-apache-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: php-apache
spec:
  ports:
    - port: 80
  selector:
    app: php-apache
EOF

kubectl apply -f php-apache-service.yaml
```

#### 创建一个`HPA`控制器
使 Pod 的副本数量在维持在1到10之间
大致来说，HPA 将通过增加或者减少 Pod 副本的数量（通过 Deployment ）以保持所有 Pod 的平均CPU利用率在50%以内 

```Bash
cat <<EOF >php-apache-hpa.yaml
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
EOF

kubectl apply -f php-apache-hpa.yaml
```

查看已经创建的`HPA`

```Bash
# kubectl get hpa
NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   <unknown>/50%   1         10        0          10s
```

创建前30秒`CPU指标`都是 \<unknown\>
如果超过时间后还是 \<unknown\> ,检查下`metrics-server` 是否运行成功

**小提示**

```Bash
## 下面这条命令可以实时监控HPA负载情况
watch -n 1 kubectl get hpa
```

-----------------------------------
#### 开始负载
另外启动一个容器，并通过一个循环向 php-apache 服务器发送无限的查询请求

```Bash
kubectl run -i --tty load-generator --image=busybox /bin/sh

while true; do wget -q -O- http://php-apache; done
```

或者直接对`Service`的虚拟`ClusterIP`地址进行访问

```Bash
# kubectl get svc php-apache

NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
php-apache   ClusterIP   10.96.173.5   <none>        80/TCP    21m

## 增加负载
while true; do wget -q -O- http://10.96.173.5; done
```

过几分钟后,可以观察到`HPA`控制器收集到的`Pod CPU`使用率

```Bash
NAME         REFERENCE               TARGETS    MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   448%/50%   1         10        1          23m
```

再过一会查看下`php-apache`的副本数量变化

```Bash
# kubectl get deployment php-apache

NAME         READY   UP-TO-DATE   AVAILABLE   AGE
php-apache   6/9     9            6           3m18s
```

可以查看`HPA`已经根据`Pod`的`CPU`使用率的提高而进行`Pod`自动扩容

#### 停止负载
停止负载来结束我们的示例.
输入\<Ctrl\> + C / \<Command\> + C 来终止负载
然后等待几分钟后查看负载情况

```Bash
# kubectl get hpa

NAME         REFERENCE               TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   1%/50%   1         10        1          31m
```

可以看到`HPA`根据`Pod CPU`使用率的降低对副本数量进行了缩容操作

-----------------------------------
#### 一键安装`metrics server`命令

```Bash
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter03/metrics-server-1.8.yaml
```

#### 一键构建测试环境
```Bash
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter03/php-apache/php-apache-deployment.yaml 
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter03/php-apache/php-apache-service.yaml
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter03/php-apache/php-apache-hpa.yaml
```

-----------------------------------
更多学习文章在[点击访问](https://github.com/charSLee013/Kubernetes-learn)