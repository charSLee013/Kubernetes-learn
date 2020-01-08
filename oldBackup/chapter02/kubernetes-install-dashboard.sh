#!/bin/bash

cd ~

## create role
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter02/admin-user.yaml

## role binding
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter02/admin-user-role-binding.yaml

## install dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0-beta6/aio/deploy/recommended.yaml

## create p12
cp -f /etc/kubernetes/admin.conf ~/.kube/config
grep 'client-certificate-data' ~/.kube/config | head -n 1 | awk '{print $2}' | base64 -d > kubecfg.crt
grep 'client-key-data' ~/.kube/config | head -n 1 | awk '{print $2}' | base64 -d >> kubecfg.key
openssl pkcs12 -export -clcerts -inkey kubecfg.key -in kubecfg.crt -out kubecfg.p12 -name "kubernetes-client" -passout pass: 

kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')

echo -e "\r#-----------------------------+"
echo ""
echo -e "Remember to download the kubecfg.p12 and install it."
echo ""
echo -e "\r#-----------------------------+"