### K8S学习指南(二)---装K8S-dashboard web界面
##### `Kubernetes` 概述
> Kubernetes Dashboard 是一个管理Kubernetes集群的全功能Web界面，旨在以UI的方式完全替代命令行工具（kubectl 等）

---------------------------------
### 创建账号
部署之前要创建好相对应的账号和密钥

#### 创建服务账号
首先创建一个叫`admin-user`的服务账号，并放在`kubernetes-dashboard`名称空间下

```yaml
# admin-user.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kube-system
```

执行`kubectl create`:

```Bash
kubectl create -f admin-user.yaml
```

#### 绑定角色

在大多数情况下，使用`kops`或`kubeadm`任何其他流行的工具配置集群后，集群中`ClusterRole admin-Role`已经存在该集群。我们可以使用它并仅为`ClusterRoleBinding`我们创建`ServiceAccount`
```yaml
# admin-user-role-binding.yaml
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kube-system
```

执行`kubectl create`:

```Bash
kubectl create -f admin-user-role-binding.yaml
```

-----------------------------
#### 创建证书
对于API Server来说，它是使用证书进行认证的，我们需要先创建一个证书：

1. 首先找到`kubectl`命令的配置文件，默认情况下为`/etc/kubernetes/admin.conf`，复制到了`~/.kube/config`中
```Bash
cp -f /etc/kubernetes/admin.conf ~/.kube/config
```

2. 生成`client-certificate-data`
```Bash
cd ~
grep 'client-certificate-data' ~/.kube/config | head -n 1 | awk '{print $2}' | base64 -d >> kubecfg.crt
```

3. 生成`client-key-data`
```Bash
cd ~
grep 'client-key-data' ~/.kube/config | head -n 1 | awk '{print $2}' | base64 -d >> kubecfg.key
```

4. 生成`p12`
```Bash
cd ~
openssl pkcs12 -export -clcerts -inkey kubecfg.key -in kubecfg.crt -out kubecfg.p12 -name "kubernetes-client"
```

5. 下载`kubecfg.p12`到本地并导入

