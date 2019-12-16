### K8S学习指南(五)---Pod定义详解

------------------------------------

#### `Pod`定义详解

```yaml
# 版本号,例如v1
apiVerison: v1

# 类型,例如 Pod,Deployment
# 参考 https://kubernetes.io/docs/concepts/
Kind: Pod

# 元数据
metedata:

  # Pod的名称,命名规范需符合RFC1035规范
  name: string

  # Pod所属的命名空间,默认值为default
  namespace: string

  # 自定义标签列表
  labels:

  # 定义方式相当于 key : value
    - name: string

  # 自定义注解列表
  annotations:

  # 定义方式相当于 key : value
    - name: string

# Pod 中容器的详细定义
spec:

  # Pod 中的容器列表
  containers:

    # 容器名称,需要符合RFC 1035规范
    - name: string

    # 容器的镜像名称
      image: string

    # 获取镜像策略,默认值为 Always
    # Always: 表示每次都尝试重新下载镜像
    # IfNotPresent: 表示如果本地有該镜像,则使用该镜像,本地不存在时下载镜像
    # Never: 表示仅使用本地镜像
      imagePullPolicy: [Always | Never | IfNotPresent]

    # 容器的启动命令列表,如果不指定,则使用镜像打包时的自动命令,也就是 CMD / ENTRYPOINT
      command: [string]

    # 容器的启动命令参数列表
      args: [string]

    # 容器的工作目录
      workingDir: string

    # 挂载到容器内部的存储卷配置
      volumeMounts:

    # 引用 Pod 定义的共享存储卷的名称,需要使用volumes[]部分定义的共享存储卷的名称
        - name: string
        
    # 存储卷在容器内Mount的绝对路径,应少于512个字符
          mountPath: string

    # 是否为只读模式,默认值为读写模式
          readOnly: boolean

    # 容器需要暴露的端口号列表
      ports:

        # 端口名称
        - name: string

        # 容器需要监听的端口号
          containerPort: int

        # 容器所在主机需要监听的端口号,默认与containerPort相同.
        # 设置hostPort时,同一台宿主机将无法启动该容器的第二份以上的副本 (因为宿主机端口被占用了,无法绑定
          hostPort: int

        # 端口协议.支持TCP 和 UDP,默认值为 TCP
          protocol: string

      # 容器运行需要设置的环境变量列表
      env:

      # 设置方法类似于 key : value
        - name: string
          value: string
      
      # 资源限制和资源请求的设置
      resources:

      # 资源限制的设置
        limits:
          # CPU 限制,单位为 m.最小可以设置 1m ,即 0.001(cpu)
          cpu: string

          # 内存限制,单位可以为 MiB/GiB/Mi 等
          memory: string

        # 资源初始分配.
        requests:

          #  CPU 要求.一般用于 Pod 调度
          # 比如设置 cpu : "32"
          # 则表明需要有node配备 32vCPU 才会被调度
          # 否则APIServer 会报错提示说没有资源进行分配,即使实际情况下用不到这么大
          cpu: string

          # 同上.同上
          memory: string
      
      # 检测容器是否准备好服务请求。如果就绪探针失败，则端点控制器将从与Pod匹配的所有服务的端点中删除Pod的IP地址。初始延迟之前的默认就绪状态为Failure
      readinessProbe:
        tcpSocket:
          port: int

      # 告诉kubelet在执行第一个探测之前应等待 int 秒
        initialDelaySeconds: int

      # 检测容器是否正在运行。如果活动探针失败，kubelet 将终止容器，容器将受其重新启动策略的影响
      livenessProbe:
        exec:

          # 执行命令,例子如下
          # command:
          # - cat
          # - /tmp/healthy
          # 如果 command 执行成功,返回 0 认为Pod为 Started 状态.
          # 如果 command 执行失败,则认为Pod为 Unhealthy 状态.
          # kubelet就会结束这个副本并重启一个.
          command: [string]

        # 定义一个liveness HTTP请求
        httpGet:
        # 在 HTTP 服务器上访问的路径
          path: string

        # 要在容器上访问的端口的名称或编号。数字必须位于 1 到 65535 的范围内。
          port: int

        # 要连接到的主机名，默认为 Pod IP
          host: string

        # 用于连接到主机（HTTP 或 HTTPS）的方案。默认为 HTTP。
          scheme: string

        # 要在请求中设置的自定义标头。HTTP 允许重复标头。
          httpHeaders:
            - name: string
              value: string

        # 使用 TCP 套接字。使用此配置，kubelet 将尝试打开指定端口上的容器的套接字。如果它可以建立连接，则容器将被视为正常，如果不能，则被视为失败
        tcpSocket:
          port: int

        # 执行探测的频率（以秒为单位）。默认为 10 秒。最小值为 1
        initialDelaySeconds: int

        # 超时设置 int 秒
        timeoutSeconds: int

        # 规定kubelet要每隔 int 秒执行一次liveness probe
        periodSeconds: int

        # 探测失败后被认为成功的最小连续成功次数
        # 如果失败然后连续 int 次成功才会被当作正常
        # 默认值为 1.最小值为 1.
        successThreshold: int

        #当Pod启动并且探针失败时，Kubernetes会继续尝试
        #当failureThreshold多次后才会放弃并重新启动容器
        # 如果准备就绪，则将Pod标记为 Unready
        # 默认值为3。最小值为1
        # 最糟糕的启动时间应该为 failureThreshold * periodSeconds
        # 超过此时间会根据策略进行操作
        failureThreshold: int

      # 容器重启策略
      # 具体情况略多,可以翻阅 https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/ 查看详情
      restartPolicy: [Always | Never | OnFailure]

      # node 过滤器.以 key :value 方式指定
      nodeSelector: object

      # 要从私有注册表中提取映像,Kubernetes需要凭据
      # imagePullSecrets配中的字段指定 Kubernetes 凭据的名称
      imagePullSecrets:
        - name: string

      # 是否使用主机网络模式.默认值为false
      # 如果设置为true,则表示容器使用宿主机网络,不再使用docker 网桥
      # 该Pod无法在同一台宿主机上启动两个以上副本
      hostNetwork: false

      # 在该Pod上定义的共享存储卷列表
      volumes:

      # 共享存储卷的名称,应符合RFC1035规范
      # 可以定义多个 volume,每个volume的 name 保持唯一
      # Volume 支持类型可以参考 https://kubernetes.io/docs/concepts/storage/volumes/
        - name: string

      # 类型为 emptyDir的存储卷,表示与Pod同生命周期的一个临时目录,其值为一个空对象: emptyDir: {}
          emptyDir: {}

      # 类型为 hostPath的存储卷,表示挂载Pod所在宿主机的目录
          hostPath:

     # 通过 spec.volumes[].hostPath.path 指定挂载到宿主机具体目录
            path: string

      # 类型为 secret 的存储卷,表示挂载集群预定义的secret对象到容器内部
          secret:
            secreName: string
            items:
              - key: string
                path: string

```

-----------------------------------
更多学习文章在[点击访问](https://github.com/charSLee013/Kubernetes-learn)