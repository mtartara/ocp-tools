#!/bin/bash

# https://access.redhat.com/solutions/5925951

RED='\033[0;31m'
NC='\033[0m' # No Color
GREEN='\033[0;32m'

echo "################################"
echo "##### API"
echo -en "external-loadbalancer-serving-certkey$ ${GREEN}secret${NC} in openshift-kube-apiserver ${GREEN}project${NC} ${RED}expires${NC} -> "
oc get secret -n openshift-kube-apiserver external-loadbalancer-serving-certkey -o yaml -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
echo -en "internal-loadbalancer-serving-certkey ${GREEN}secret${NC} in openshift-kube-apiserver ${GREEN}project${NC} ${RED}expires${NC} -> "
oc get secret -n openshift-kube-apiserver internal-loadbalancer-serving-certkey -o yaml -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
echo "---------------------"

echo -e "\n"
echo "################################"
echo  "##### Kube Controller Manager"
echo -en "kube-scheduler-client-cert-key ${GREEN}secret${NC} in openshift-kube-controller-manager ${GREEN}project${NC} ${RED}expires${NC} -> "
oc get secret kube-controller-manager-client-cert-key -n openshift-kube-controller-manager -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
echo -en "serving-cert ${GREEN}secret${NC} in openshift-kube-controller-manager ${GREEN}project${NC} ${RED}expires${NC} -> "
oc get secret serving-cert -n openshift-kube-controller-manager -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
echo "---------------------"

echo -e "\n"
echo "################################"
echo  "##### Kube Scheduler"
echo -en "kube-scheduler-client-cert-key ${GREEN}secret${NC} in openshift-kube-scheduler ${GREEN}project${NC} ${RED}expires${NC} -> "
oc get secret kube-scheduler-client-cert-key -n openshift-kube-scheduler -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
echo -en "serving-cert ${GREEN}secret${NC} in openshift-kube-scheduler ${GREEN}project${NC} ${RED}expires${NC} -> "
oc get secret serving-cert -n openshift-kube-scheduler -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
echo "---------------------"

echo -e "\n"
echo "################################"
echo  "##### ETCD Certificates #####"
for master in $(oc get nodes -oname -l "node-role.kubernetes.io/master"|cut -d/ -f2); do
  echo "----"
  echo -en "etcd-peer-$master ${GREEN}secret${NC} in openshift-etcd ${GREEN}project${NC} ${RED}expires${NC} ->  "
  oc get -n openshift-etcd secret etcd-peer-"$master" -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
  echo -en "etcd-serving-$master ${GREEN}secret${NC} in openshift-etcd ${GREEN}project${NC} ${RED}expires${NC} ->  "
  oc get -n openshift-etcd secret etcd-serving-"$master"  -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
  echo -en "etcd-serving-metrics-$master ${GREEN}secret${NC} in openshift-etcd ${GREEN}project${NC} ${RED}expires${NC} ->  "
  oc get -n openshift-etcd secret etcd-serving-metrics-"$master" -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
done
echo "---------------------"

echo -e "\n"
echo "################################"
echo  "##### Node Certificates #####"
for node in $(oc get nodes -oname|cut -d/ -f2); do
  #echo "## Node: $node";
  echo "------------- node: $node -------------"
  echo -en "kubelet-client-current ${RED}expires${NC} ->  "
  ssh -o StrictHostKeyChecking=no "$node" -lcore sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -enddate -dateopt iso_8601
  echo -en "kubelet-server-current ${RED}expires${NC} ->  "
  ssh -o StrictHostKeyChecking=no "$node" -lcore sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-server-current.pem -noout -enddate -dateopt iso_8601
done
echo "---------------------------------------"

echo -e "\n"
echo "################################"
echo  "##### Ingress Certificates #####"
echo -en "router-certs-default ${GREEN}secret${NC} in openshift-ingress ${GREEN}project${NC} ${RED}expires${NC} ->  "
oc get secret router-certs-default  -oyaml -n openshift-ingress | grep crt | awk '{print $2}' | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
echo "---------------------"
