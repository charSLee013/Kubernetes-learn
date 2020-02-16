### Kubernetes学习指南(四)--创建Ingress并设置TLS

Ingress 公开了从集群外部到集群内`Services`的`HTTP`和`HTTPS`路由,访问流量路由由**Ingress**资源上定义的规则控制。

------------------------------

##### Ingress: HTTP 7层路由机制

使用`Ingress`进行负载均衡时,`Ingress Controller`将基于`Ingress`规则将客户端请求直接转发到`Service`对应的后端`Endpoint`(即`Pod`)上,这样会跳过`kube-proxy`的转发功能.

如果`Ingress Controller`提供的是对外服务,则实际上实现的就是边缘路由器(边缘路由器是在网络的边界点用于与其他网络(例如Intemet)相连接的路由器)的功能.

```
    Internet
        |
   [ mywebsite.com (Ingress Controller) ]
   -----------|-----------|------------|
   /api       /web        /cmd
   |          |           |
   |          |           |
   ↓          ↓           ↓
[  API        WEB         CMD           ]
```

* 对`http://mywebsite.com/api`的访问将被路由到后端`API`的`Service`
* 对`http://mywebsite.com/web`的访问将被路由到后端`WEB`的`Service`
* 对`http://mywebsite.com/cmd`的访问将被路由到后端`CMD`的`Service`




------------------------------

### 创建`Ingress Controller`

#### 环境准备

开始之前先明确机器所处环境,如果是在GCE,Azure,AWS等云服务提供商,可以直接使用云服务提供商的**LoadBalancer**,具体可以参考[此链接](https://kubernetes.github.io/ingress-nginx/deploy/).

以下例子是基于裸机(公网IP + 内网互联)组成,使用谷歌提供的`Nginx-ingress-controller`来创建`Ingress Controller`

#### `Ingress Controller`服务

在`Kubernetes`中,`Ingress Controller`将以`Pod`的形式运行,监控`Apiserver`的`Ingress`接口,如果`Service`有发生`CRUD`,则`Ingress Controller`自动更新转发规则.

实现的基本逻辑如下:
* 创建相对应权限的`Role`,监听`Apiserver`,获取全部`Ingress`的定义
* 基于`Ingress`的定义,生成`Nginx`所需的配置文件`/etc/nginx/nginx.conf`
* 执行`nginx -s reload`命令,重新加载`nginx.conf`配置文件的内容


本例使用谷歌提供的[NGINX Ingress Controller]("https://kubernetes.github.io/ingress-nginx/") 镜像来创建`Ingress Controller`
该`Ingress Controller`以`Daemonset`的形式进行创建,在每个`Node`上都创建一个`Nginx`服务,用来监听`HTTP`(80) `HTTPS`(443)
**注:如果你的网络域有云厂商提供的负载均衡,请参考 `https://kubernetes.github.io/ingress-nginx/deploy/` 中不同厂商的特定步骤**


#### 创建`Nginx Ingress Controller`
下载部署文件
```Bash
wget -O nginx-ingress-controller.yaml https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.29.0/deploy/static/mandatory.yaml

## 或者直接下载修改完成的部署文件
wget -O nginx-ingress-controller.yaml https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter04/nginx-ingress-controller.yaml
```

修改如下:
```Bash
          args:
            ...
            ...
            - --default-backend-service=$(POD_NAMESPACE)/nginx-errors   ## 默认错误导向
            - --v=3   ## debug模式,仅在调试下使用
```

* 默认的`backend`,用于在客户端访问的`URL`地址不存在时能返回一个正确应答404应发.
* 开启**debug**模式 `--v=3`,只适用于开发环境
* 注释了`LimitRange`的性能限制,增大性能上限

###### 部署命令

```Bash
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter04/nginx-ingress-controller.yaml
```

