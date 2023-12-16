#!/bin/bash
set -eux

WORK_DIR=$(pwd)
SCRIPT_DIR=$(cd $(dirname $0); pwd)
CONFIG_DIR=${SCRIPT_DIR}/config
mkdir -p ${CONFIG_DIR}

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# create cluster.
cd ${SCRIPT_DIR}
kind create cluster --config kind-cluster.yaml
sleep 10 &
wait

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# install external snapshotter
cd ${SCRIPT_DIR}
rm -rf external-snapshotter
git clone https://github.com/kubernetes-csi/external-snapshotter.git external-snapshotter
cd external-snapshotter
kubectl kustomize client/config/crd | kubectl create -f -
kubectl -n kube-system kustomize deploy/kubernetes/snapshot-controller | kubectl create -f -

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# install synology csi driver. 
cd ${SCRIPT_DIR}
rm -rf synology-csi
git clone https://github.com/SynologyOpenSource/synology-csi.git synology-csi
cd synology-csi
sed -ie 's/ --short//' scripts/deploy.sh
cp ${CONFIG_DIR}/synology/synology-client-info.yml \
   config/client-info.yml
rm deploy/kubernetes/v1.20/storage-class.yml
cp ${CONFIG_DIR}/synology/*.yaml \
   deploy/kubernetes/v1.20/
rm deploy/kubernetes/v1.20/namespace.yml
./scripts/deploy.sh install --all

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# apply ingress NGINX.
cd ${SCRIPT_DIR}
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
sleep 10 &
wait
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=600s

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# apply argocd.
cd ${SCRIPT_DIR}
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
