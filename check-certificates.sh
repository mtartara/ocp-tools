#!/bin/bash
# shellcheck disable=SC2029
# shellcheck disable=SC2206
# https://access.redhat.com/solutions/5925951

function usage(){
    echo "Script Version 1.0
    usage: check-certificates.sh [-e] [-h]

    Optional arguments:
    pattern                         host pattern
    -e,                             To set the missing DAYS to check before Certificates EXPIRES (Default 60 Days)
    -h, --help                      Show this help message and exit
    ––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––
    "
}

# Set Shell TEXT COLOR
RED='\033[0;31m' # RED
NC='\033[0m' # No Color
GREEN='\033[0;32m'

# Default Missing Days before CERTS expire
DAYS_NUMBER=30

# Set Optional arguments if present
if [ "$1" != "" ]; then
    while [ "$1" != "" ]; do
      case $1 in
          -e )                    [[ $2 =~ ^[0-9]+$ ]] && shift && DAYS_NUMBER=$1
                                  ;;
          -h | --help )           usage
                                  exit
                                  ;;
          * )                     usage
                                  echo -e "Error for args: $1\n"
                                  exit 1
      esac
      shift
    done
fi

function show_cert() {
  ## - Do not use `openssl x509 -in` command which can only handle first cert in a given input
  CERT_VALIDITY=$(openssl crl2pkcs7 -nocrl -certfile /dev/stdin | openssl pkcs7 -print_certs -text \
    | openssl x509  -enddate -noout -dateopt iso_8601 -checkend $((60*60*24*DAYS_NUMBER)))
  if [ $? == 0 ]; then
    echo -ne "${GREEN}"
    echo "${CERT_VALIDITY}"
    echo -ne "${NC}"
  else
    echo -ne "${RED}"
    echo -e "${CERT_VALIDITY} within ${DAYS_NUMBER} days"
    echo -ne "${NC}"
  fi
}

echo "################################"
echo -e "##### ${GREEN}API${NC} #####"
echo -en "external-loadbalancer-serving-certkey secret in openshift-kube-apiserver project ${RED}expires${NC} -> "
oc get secret -n openshift-kube-apiserver external-loadbalancer-serving-certkey -o yaml -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
echo -en "internal-loadbalancer-serving-certkey secret in openshift-kube-apiserver project ${RED}expires${NC} -> "
oc get secret -n openshift-kube-apiserver internal-loadbalancer-serving-certkey -o yaml -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
echo "---------------------"

echo -e "\n"
echo "################################"
echo -e "##### ${GREEN}Kube Controller Manager${NC} #####"
echo -en "kube-scheduler-client-cert-key secret in openshift-kube-controller-manager project ${RED}expires${NC} -> "
oc get secret kube-controller-manager-client-cert-key -n openshift-kube-controller-manager -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
echo -en "serving-cert secret in openshift-kube-controller-manager project ${RED}expires${NC} -> "
oc get secret serving-cert -n openshift-kube-controller-manager -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
echo "---------------------"

echo -e "\n"
echo "################################"
echo  -e "##### ${GREEN}Kube Scheduler${NC} #####"
echo -en "kube-scheduler-client-cert-key secret in openshift-kube-scheduler project ${RED}expires${NC} -> "
oc get secret kube-scheduler-client-cert-key -n openshift-kube-scheduler -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
echo -en "serving-cert secret in openshift-kube-scheduler project ${RED}expires${NC} -> "
oc get secret serving-cert -n openshift-kube-scheduler -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
echo "---------------------"

echo -e "\n"
echo "################################"
echo  -e "##### ${GREEN}ETCD Certificates${NC} #####"
for master in $(oc get nodes -oname -l "node-role.kubernetes.io/master"|cut -d/ -f2); do
  echo "----"
  echo -en "etcd-peer-$master secret in openshift-etcd project ${RED}expires${NC} ->  "
  oc get -n openshift-etcd secret etcd-peer-"$master" -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
  echo -en "etcd-serving-$master secret in openshift-etcd project ${RED}expires${NC} ->  "
  oc get -n openshift-etcd secret etcd-serving-"$master"  -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
  echo -en "etcd-serving-metrics-$master secret in openshift-etcd project ${RED}expires${NC} ->  "
  oc get -n openshift-etcd secret etcd-serving-metrics-"$master" -o=custom-columns=":.data.tls\.crt" | tail -1 | base64 -d | show_cert
done
echo "---------------------"

echo -e "\n"
echo "################################"
echo  -e "##### ${GREEN}Node Certificates${NC} #####"
for node in $(oc get nodes -oname|cut -d/ -f2); do
  #echo "## Node: $node";
  echo -e "------------- ${GREEN}node: $node${NC} -------------"
  echo -en "kubelet-client-current ${RED}expires${NC} ->  "
  #ssh -o StrictHostKeyChecking=no "$node" -lcore sudo openssl x509 -in /var/lib/kubelet/pki/kubelet-client-current.pem -noout -enddate -dateopt iso_8601
  ssh -o StrictHostKeyChecking=no "$node" -lcore sudo cat /var/lib/kubelet/pki/kubelet-client-current.pem | show_cert
  echo -en "kubelet-server-current ${RED}expires${NC} ->  "
  ssh -o StrictHostKeyChecking=no "$node" -lcore sudo cat /var/lib/kubelet/pki/kubelet-server-current.pem | show_cert
done
echo "---------------------------------------"

echo -e "\n"
echo "################################"
echo  -e "##### ${GREEN}Ingress Certificates${NC} #####"
echo -en "router-certs-default secret in openshift-ingress project ${RED}expires${NC} ->  "
oc get secret router-certs-default  -oyaml -n openshift-ingress | grep crt | awk '{print $2}' | base64 -d | show_cert
echo "---------------------"
