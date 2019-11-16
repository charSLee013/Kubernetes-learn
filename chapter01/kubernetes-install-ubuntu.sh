#!/bin/bash

## close swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

## update
apt-get update


## install docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update && sudo apt install -y docker-ce
sudo systemctl enable docker
systemctl start docker

## ready
apt-get install -y curl wget apt-transport-https

## install Minikube
wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x ./minikube-linux-amd64
cp minikube-linux-amd64 /usr/local/bin/minikube


## chcek minikube  version
minikube version

## install Kubectl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install kubectl -y
sudo apt install -y kubeadm  kubernetes-cni

## check kubectl
kubectl version -o json

## minikube cleanup and start
minikube delete
# debug
# minikube start --vm-driver=none --alsologtostderr -v=8
minikube start --vm-driver=none --extra-config=apiserver.Authorization.Mode=RBAC
export CHANGE_MINIKUBE_NONE_USER=true

echo -e "\r#-----------------------------+"
echo ""
echo "K8S has been installed..."
echo ""
echo "#-----------------------------+"

## check cluster
# kubectl cluster-info

# kubectl config view

# kubectl get nodes

# ## list minikube
# minikube addons list

# ## list  container image
# kubectl get pods --all-namespaces

# ## get the URL of the kubernate dashboard
# minikube dashboard --url