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
kubectl apply -f 
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
#### 创建

-----------------------------------
更多学习文章在[点击访问](https://github.com/charSLee013/Kubernetes-learn)