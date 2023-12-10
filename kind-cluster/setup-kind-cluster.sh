#!/bin/bash
set -eux

WORK_DIR=$(pwd)
SCRIPT_DIR=$(cd $(dirname $0); pwd)
CONFIG_DIR=${SCRIPT_DIR}/config
mkdir -p ${CONFIG_DIR}

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# create cluster.
cd ${SCRIPT_DIR}
kind create cluster --config ${SCRIPT_DIR}/kind-cluster.yaml
cd ${WORK_DIR}
sleep 10 &
wait

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# apply ingress NGINX.
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
sleep 10 &
wait
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=600s

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# apply argocd.
helm repo add argo https://argoproj.github.io/argo-helm
helm install \
  --create-namespace --namespace argo-cd \
  argo-cd \
  argo/argo-cd \
  --version 5.45.5 \
  -f ${SCRIPT_DIR}/argo-cd.values.yaml
sleep 10 &
wait
kubectl wait --namespace argo-cd \
  --for=condition=ready \
  --all pods \
  --timeout=600s
echo $(kubectl -n argo-cd get secret/argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) > ${CONFIG_DIR}/argo-cd-default-pw.txt
