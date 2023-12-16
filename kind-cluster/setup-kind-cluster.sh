#!/bin/bash
set -eux

WORK_DIR=$(pwd)
SCRIPT_DIR=$(cd $(dirname $0); pwd)
CONFIG_DIR=${SCRIPT_DIR}/config
mkdir -p ${CONFIG_DIR}
cd ${SCRIPT_DIR}

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# create cluster.
kind create cluster --config kind-cluster.yaml
cd ${WORK_DIR}
sleep 10 &
wait

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# install external snapshotter
rm -rf external-snapshotter
git clone https://github.com/kubernetes-csi/external-snapshotter.git external-snapshotter
cd external-snapshotter
kubectl kustomize client/config/crd | kubectl create -f -
kubectl -n kube-system kustomize deploy/kubernetes/snapshot-controller | kubectl create -f -
cd ${SCRIPT_DIR}

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# install synology csi driver. 
rm -rf synology-csi
git clone https://github.com/SynologyOpenSource/synology-csi.git synology-csi
sed -ie 's/ --short//' synology-csi/scripts/deploy.sh
cp ${CONFIG_DIR}/synology/synology-client-info.yml \
   synology-csi/config/client-info.yml
rm synology-csi/deploy/kubernetes/v1.20/storage-class.yml
cp ${CONFIG_DIR}/synology/*.yaml \
   synology-csi/deploy/kubernetes/v1.20/
rm synology-csi/deploy/kubernetes/v1.20/namespace.yml
# synology-csi/scripts/deploy.sh install --basic
synology-csi/scripts/deploy.sh run

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
  -f argo-cd.values.yaml
sleep 10 &
wait
kubectl wait --namespace argo-cd \
  --for=condition=ready \
  --all pods \
  --timeout=600s
echo $(kubectl -n argo-cd get secret/argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) > ${CONFIG_DIR}/argo-cd-default-pw.txt
