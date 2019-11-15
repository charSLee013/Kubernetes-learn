#!/bin/bash

echo 'Please make sure your system is centos 7+'

## close firewall
systemctl disable firewalld
systemctl stop firewalld

## install crt and K8S
yum update -y && yum install -y etcd kubernetes
wget http://mirror.centos.org/centos/7/os/x86_64/Packages/python-rhsm-certificates-1.19.10-1.el7_4.x86_64.rpm
rpm2cpio python-rhsm-certificates-1.19.10-1.el7_4.x86_64.rpm | cpio -iv --to-stdout ./etc/rhsm/ca/redhat-uep.pem | tee /etc/rhsm/ca/redhat-uep.pem


## fix ServiceAccount
sed -i "s/ServiceAccount,//g" /etc/kubernetes/apiserver


## start K8S
systemctl restart etcd
systemctl restart docker
systemctl restart kube-apiserver
systemctl restart kube-controller-manager
systemctl restart kube-scheduler
systemctl restart kubelet
systemctl restart kube-proxy