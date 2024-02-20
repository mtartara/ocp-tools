#!/bin/bash

# https://access.redhat.com/solutions/5925951

echo "################################"
echo "##### API"
echo "## External API"
oc get secret -n openshift-kube-apiserver external-loadbalancer-serving-certkey -o yaml -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -dates
echo "---------------------"
echo "## Internal API"
oc get secret -n openshift-kube-apiserver internal-loadbalancer-serving-certkey -o yaml -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -dates

echo "################################"
echo  "##### Kube Controller Manager"

echo "## Client certificate"
oc get secret kube-controller-manager-client-cert-key -n openshift-kube-controller-manager -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -dates
echo "---------------------"
echo "## Server certificate"
oc get secret serving-cert -n openshift-kube-controller-manager -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -dates

echo "################################"
echo  "##### Kube Scheduler"
echo "## Client certificate"
oc get secret kube-scheduler-client-cert-key -n openshift-kube-scheduler -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -dates
echo "---------------------"
echo "# Server certificate"
oc get secret serving-cert -n openshift-kube-scheduler -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -dates

echo "################################"
echo  "##### ETCD Certificates"
for master in $(oc get nodes -oname -l "node-role.kubernetes.io/master"|cut -d/ -f2); do
  echo "## Node: $master";
  echo "# etcd-peer-$master certificate";
  oc get -n openshift-etcd secret etcd-peer-"$master" -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -dates;
  echo "# etcd-serving-$master certificate";
  oc get -n openshift-etcd secret etcd-serving-"$master"  -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -dates;
  echo "# etcd-serving-metrics-$master certificate";
  oc get -n openshift-etcd secret etcd-serving-metrics-"$master" -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | openssl x509 -noout -dates;
  echo "---------------------";
done

echo "################################"
echo  "##### Node Certificates"
for node in $(oc get nodes -oname|cut -d/ -f2); do
  echo "## Node: $node";
  echo "# kubelet-client-current";
  ssh "$node" -lcore sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -dates;
  echo "# kubelet-server-current";
  ssh "$node" -lcore sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-server-current.pem -noout -dates;
  sleep 1;
  echo "---------------------";
done