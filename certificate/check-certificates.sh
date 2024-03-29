#!/bin/bash
# shellcheck disable=SC2029
# shellcheck disable=SC2206
# https://access.redhat.com/solutions/5925951
#
# Author Matteo Tartara
#

# Default Missing Days before CERTS expire
DAYS_NUMBER=15

CHECK_TYPE="all"

function usage(){
    echo "Script Version 1.0
    usage: check-certificates.sh [-d] [-o] [-h]

    Optional arguments:
    pattern                         host pattern
    -d,                             To set the missing DAYS to check before Certificates EXPIRES. (Default $DAYS_NUMBER Days)
    -t,                             The type of check that you want. [api,kube-controller,kube-scheduler,etcd,ca,ingress,nodes,all] (Default $CHECK_TYPE)
    -h,                             Show this help message and exit.
    ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    "
}

# Set Shell TEXT COLOR
RED='\033[0;31m' # RED
NC='\033[0m' # No Color
GREEN='\033[0;32m'
BLUE='\033[1;34m'
YELLOW='\033[0;33m'


OPTSTRING=":d:t:h"

while getopts ${OPTSTRING} opt; do
  case ${opt} in
    d)
      [[ $2 =~ ^[0-9]+$ ]] && shift && DAYS_NUMBER=$OPTARG
      ;;
    t)
      CHECK_TYPE=$OPTARG
      ;;
    h)
      usage
      exit
      ;;
    *)
      echo "Invalid option: -${OPTARG}."
      usage
      exit 1
      ;;
  esac
done

IFS="," read -ra selected_check <<< "$CHECK_TYPE"

function show_cert() {
  ## - Do not use `openssl x509 -in` command which can only handle first cert in a given input
  CERT_VALIDITY=$(openssl crl2pkcs7 -nocrl -certfile /dev/stdin | openssl pkcs7 -print_certs -text \
	  | openssl x509  -enddate -noout -dateopt iso_8601 -checkend $((60*60*24*DAYS_NUMBER)))
  if [ $? == 0 ]; then
    echo -ne "${GREEN}"
    echo -ne "${CERT_VALIDITY}" | xargs | awk '{printf $1" "$2"\033[0m =========> \033[0;32m"}'
    echo -e "CERTIFICATE WILL NOT EXPIRE WITHIN ${DAYS_NUMBER} DAYS"
    echo -ne "${NC}"
  else
    echo -ne "${RED}"
    echo -en "${CERT_VALIDITY}" | xargs | awk '{printf $1" "$2"\033[0m =========> \033[0;31m"}'
    echo -e "CERTIFICATE WILL EXPIRE WITHIN ${DAYS_NUMBER} DAYS"
    echo -ne "${NC}"
  fi
}

function api() {
  echo "################################"
  echo -e "##### ${BLUE}API${NC} #####"
  echo -ne "${YELLOW}"
  echo "# The serving cert and key pair used by both internal and external API are stored inside the secrets in the namespace openshift-kube-apiserver."
  echo -ne "${NC}"
  echo -en "${BLUE}PROJECT${NC}: openshift-kube-apiserver ${BLUE}SECRET${NC}: external-loadbalancer-serving-certkey --> ${BLUE}EXPIRES${NC} "
  oc get secret -n openshift-kube-apiserver external-loadbalancer-serving-certkey -o yaml -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
  echo -en "${BLUE}PROJECT${NC}: openshift-kube-apiserver ${BLUE}SECRET${NC}: internal-loadbalancer-serving-certkey --> ${BLUE}EXPIRES${NC} "
  oc get secret -n openshift-kube-apiserver internal-loadbalancer-serving-certkey -o yaml -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
  echo "---------------------"
}

function kube-controller(){
  echo
  echo "################################"
  echo -e "##### ${BLUE}Kube Controller Manager${NC} #####"
  echo -en "${BLUE}PROJECT${NC}: openshift-kube-controller-manager ${BLUE}SECRET${NC}: kube-scheduler-client-cert-key --> ${BLUE}EXPIRES${NC} "
  oc get secret kube-controller-manager-client-cert-key -n openshift-kube-controller-manager -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
  echo -en "${BLUE}PROJECT${NC}: openshift-kube-controller-manager ${BLUE}SECRET${NC}: serving-cert --> ${BLUE}EXPIRES${NC} "
  oc get secret serving-cert -n openshift-kube-controller-manager -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
  echo "---------------------"
}

function kube-scheduler(){
  echo
  echo "################################"
  echo  -e "##### ${BLUE}Kube Scheduler${NC} #####"
  echo -en "${BLUE}PROJECT${NC}: openshift-kube-scheduler ${BLUE}SECRET${NC}: kube-scheduler-client-cert-key --> ${BLUE}EXPIRES${NC} "
  oc get secret kube-scheduler-client-cert-key -n openshift-kube-scheduler -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
  echo -en "${BLUE}PROJECT${NC}: openshift-kube-scheduler ${BLUE}SECRET${NC}: serving-cert --> ${BLUE}EXPIRES${NC} "
  oc get secret serving-cert -n openshift-kube-scheduler -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
  echo "---------------------"
}

function etcd(){
  echo
  echo "################################"
  echo  -e "##### ${BLUE}ETCD certificates${NC} #####"
  echo -ne "${YELLOW}"
  echo "# The etcd-peer certificate is used for the etcd peer-to-peer communication."
  echo "# The etcd-serving certificate is used as the serving certificate by each etcd host."
  echo "# The etcd-serving-metrics certificate is used for getting the etcd metrics."
  echo -ne "${NC}"
  for master in $(oc get nodes -oname -l "node-role.kubernetes.io/master"|cut -d/ -f2); do
    echo -en "${BLUE}PROJECT${NC}: openshift-etcd ${BLUE}SECRET${NC}: etcd-peer-$master --> ${BLUE}EXPIRES${NC} "
    #oc get -n openshift-etcd secret etcd-peer-"$master" -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
    oc get -n openshift-etcd secret etcd-peer-"$master" -o template='{{index .data "tls.crt"}}' | base64 -d | show_cert
    echo -en "${BLUE}PROJECT${NC}: openshift-etcd ${BLUE}SECRET${NC}: etcd-serving-$master --> ${BLUE}EXPIRES${NC} "
    #oc get -n openshift-etcd secret etcd-serving-"$master"  -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
    oc get -n openshift-etcd secret etcd-serving-"$master" -o template='{{index .data "tls.crt"}}' | base64 -d | show_cert
    echo -en "${BLUE}PROJECT${NC}: openshift-etcd ${BLUE}SECRET${NC}: etcd-serving-metrics-$master --> ${BLUE}EXPIRES${NC} "
    #oc get -n openshift-etcd secrets/etcd-serving-metrics-"$master" -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
    oc get -n openshift-etcd secrets/etcd-serving-metrics-"$master" -o template='{{index .data "tls.crt"}}' | base64 -d | show_cert
    echo "----"
  done
  echo "---------------------"
}

function ingress(){
  echo
  echo "################################"
  echo -e "##### ${BLUE}Ingress certificates${NC} #####"
  echo "# Used by the ingress router and all the secured routes are using this cert, unless a cert-key pair is explicitly provided through the route YAML."
  echo -en "${BLUE}PROJECT${NC}: openshift-ingress ${BLUE}SECRET${NC}: router-certs-default --> ${BLUE}EXPIRES${NC} "
  #oc get secret router-certs-default  -oyaml -n openshift-ingress | grep crt | awk '{print $2}' | base64 -d | show_cert
  oc get secrets/router-certs-default -n openshift-ingress -o template='{{index .data "tls.crt"}}' | base64 -d | show_cert
  echo "---------------------"
}

function ca(){
  echo
  echo "################################"
  echo -e "##### ${BLUE}Service-signer certificates${NC} #####"
  echo -ne "${YELLOW}"
  echo "# Service serving certificates are signed by the service-CA and has a validty of 2 years by default."
  echo -ne "${NC}"
  echo -en "${BLUE}PROJECT${NC}: openshift-ingress ${BLUE}SECRET${NC}: router-certs-default --> ${BLUE}EXPIRES${NC} "
  oc get secrets/signing-key -n openshift-service-ca -o template='{{index .data "tls.crt"}}' | base64 -d | show_cert
  echo "---------------------"
}

function nodes(){
  echo
  echo "################################"
  echo -e "##### ${BLUE}Node Certificates${NC} #####"
  echo -ne "${YELLOW}"
  echo "# kubelet-client-current.pem = Which is used as the kubelet client cert."
  echo "# kubelet-server-current.pem = Which is used as the kubelet server cert."
  echo "# There are other PEM files that are already rotated certs and also the symlinks of the above 2 certs."
  echo -ne "${NC}"
  for node in $(oc get nodes -oname|cut -d/ -f2); do
    #echo "## Node: $node";
    echo -e "------------- node: ${BLUE}$node${NC} -------------"
    echo -en "${BLUE}CERTIFICATE${NC}: kubelet-client-current --> ${BLUE}EXPIRES${NC} "
    ssh -o StrictHostKeyChecking=no "$node" -lcore sudo cat /var/lib/kubelet/pki/kubelet-client-current.pem | show_cert
    echo -en "${BLUE}CERTIFICATE${NC}: kubelet-server-current --> ${BLUE}EXPIRES${NC} "
    ssh -o StrictHostKeyChecking=no "$node" -lcore sudo cat /var/lib/kubelet/pki/kubelet-server-current.pem | show_cert
  done
  echo "---------------------------------------"
}

function all(){
  api
  kube-controller
  kube-scheduler
  etcd
  ingress
  ca
  nodes
}

for element in "${selected_check[@]}"; do
  $element
done
