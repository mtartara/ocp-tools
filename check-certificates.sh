#!/bin/bash

# https://access.redhat.com/solutions/5925951

echo "################################"
echo "##### API"
echo -en "external-loadbalancer-serving-certkey secret in openshift-kube-apiserver project expires -> "
oc get secret -n openshift-kube-apiserver external-loadbalancer-serving-certkey -o yaml -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
echo -en "internal-loadbalancer-serving-certkey secret in openshift-kube-apiserver project expires -> "
oc get secret -n openshift-kube-apiserver internal-loadbalancer-serving-certkey -o yaml -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
echo "---------------------"

echo -e "\n"
echo "################################"
echo  "##### Kube Controller Manager"
echo -en "kube-scheduler-client-cert-key secret in openshift-kube-controller-manager project expires -> "
oc get secret kube-controller-manager-client-cert-key -n openshift-kube-controller-manager -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
echo -en "serving-cert secret in openshift-kube-controller-manager project expires -> "
oc get secret serving-cert -n openshift-kube-controller-manager -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
echo "---------------------"

echo -e "\n"
echo "################################"
echo  "##### Kube Scheduler"
echo -en "kube-scheduler-client-cert-key secret in openshift-kube-scheduler project expires -> "
oc get secret kube-scheduler-client-cert-key -n openshift-kube-scheduler -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
echo -en "serving-cert secret in openshift-kube-scheduler project expires -> "
oc get secret serving-cert -n openshift-kube-scheduler -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
echo "---------------------"

echo -e "\n"
echo "################################"
echo  "##### ETCD Certificates #####"
for master in $(oc get nodes -oname -l "node-role.kubernetes.io/master"|cut -d/ -f2); do
  echo "----"
  echo -en "etcd-peer-$master secret in openshift-etcd project expires ->  "
  oc get -n openshift-etcd secret etcd-peer-"$master" -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
  echo -en "etcd-serving-$master secret in openshift-etcd project expires ->  "
  oc get -n openshift-etcd secret etcd-serving-"$master"  -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
  echo -en "etcd-serving-metrics-$master secret in openshift-etcd project expires ->  "
  oc get -n openshift-etcd secret etcd-serving-metrics-"$master" -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -enddate -dateopt iso_8601
done
echo "---------------------"

echo -e "\n"
echo "################################"
echo  "##### Node Certificates #####"
for node in $(oc get nodes -oname|cut -d/ -f2); do
  #echo "## Node: $node";
  echo "------------- node: $node -------------"
  echo -en "kubelet-client-current expires ->  "
  ssh -o StrictHostKeyChecking=no "$node" -lcore sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -enddate -dateopt iso_8601
  echo -en "kubelet-server-current expires ->  "
  ssh -o StrictHostKeyChecking=no "$node" -lcore sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-server-current.pem -noout -enddate -dateopt iso_8601
done
echo "---------------------"

echo -e "\n"
echo "################################"
echo  "##### Ingress Certificates #####"
echo -en "router-certs-default secret inopenshift-ingress project expires ->  "
oc get secret router-certs-default  -oyaml -n openshift-ingress | grep crt | awk '{print $2}' | base64 -d | openssl x509 -noout -dates -dateopt iso_8601
echo "---------------------"
