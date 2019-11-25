#!/bin/bash

cd ~

## create role
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter02/admin-user.yaml

## role binding
kubectl apply -f https://raw.githubusercontent.com/charSLee013/Kubernetes-learn/master/chapter02/admin-user-role-binding.yaml

## create p12
cp -f /etc/kubernetes/admin.conf ~/.kube/config
grep 'client-certificate-data' ~/.kube/config | head -n 1 | awk '{print $2}' | base64 -d > kubecfg.crt
grep 'client-key-data' ~/.kube/config | head -n 1 | awk '{print $2}' | base64 -d >> kubecfg.key
openssl pkcs12 -export -clcerts -inkey kubecfg.key -in kubecfg.crt -out kubecfg.p12 -name "kubernetes-client" -passout pass: 


echo -e "\r#-----------------------------+"
echo ""
echo -e "Remember to download the kubecfg.p12 and install it."
echo ""
echo -e "\r#-----------------------------+"