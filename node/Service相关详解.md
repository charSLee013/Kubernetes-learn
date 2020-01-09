### Kubernetes Service相关详解

------------------------------------

#### `Service`定义详解

```yaml
apiVersion: v1
kind: Service
metadata:
  ## Service名称,需符合RFC1035规范
  name: string      

  ## 命名空间,不指定系统时将使用名为"default"的命名空间
  namespace: string 
  labels:           

  ## 自定义标签属性列表
   - name: string

  ## 自定义注解属性列表
  annotations:      
    - name: string  

## 详细描述
spec:               

  ## Label Selector 配置,将选择具有指定Label 标签的Pod作为管理范围
  selector: []     
   
  ## Service 类型,指定Service的访问方式,默认值为ClusterIP;
  ## ClusterIP: 虚拟的服务IP地址,该地址用于Kubernetes 集群内部的Pod访问,在Node上kube-proxy通过设置的Iptables规则进行转发
  ## NodePort: 使用宿主主机的端口,使能够访问各Node的外部,客户端通过Node的IP地址和端口号就能访问服务
  ## LoadBalancer: 使用外接负载均衡器完成到服务的负载分发,需要在 spec.status.loadBalancer 字段指定外部负载均衡器的IP地址,并同时定义 nodePort 和 clusterIP,用于公有云环境
  type: string      

  ## 虚拟服务IP地址,当type=ClusterIP时,如果不指定,则系统进行自动分配,当type=LoadBalancer时,需要手动指定
  clusterIp: string

  ## 是否支持Session,可选值为ClientIP,默认值为空.
  ## ClientIP:表示将同一个客户端(根据客户端的IP地址决定的访问请求都转发到同一个后端Pod)
  sessionAffinity: string

  ## Service 需要暴露的端口列表
  ports:

  ## 端口名称
    - name: string

  ## 端口协议,支持TCP和UDP,默认值为TCP
      protocol: string

  ## 服务监听的端口号
      port: int
  ## 需要转发到后端Pod的端口号
      targetPort: int

  ## 当sepc.type=NodePort时,指定映射到物理机的端口号
      nodePort: int
  
  ## 当spec.type=LoadBalancer时,设置外部负载均衡器的地址,用于公有云环境
  status:

  ## 外部负载均衡器
    loadBalancer:
      ingress:
        ip: string
        hostname: string
```