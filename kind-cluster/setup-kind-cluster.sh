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

for node in $(kind get nodes -n kind-cluster); do
  echo $node
  docker exec "${node}" sed -ie 's/# node.startup = automatic/node.startup = automatic/' /etc/iscsi/iscsid.conf
  docker exec "${node}" sed -ie 's/node.startup = manual/# node.startup = manual/' /etc/iscsi/iscsid.conf
  docker exec "${node}" systemctl enable iscsid
  docker exec "${node}" systemctl start iscsid
done

# # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# # install external snapshotter
# cd ${SCRIPT_DIR}
# rm -rf external-snapshotter
# git clone -b v6.3.2 https://github.com/kubernetes-csi/external-snapshotter.git external-snapshotter
# cd external-snapshotter
# kubectl kustomize client/config/crd | kubectl create -f -
# kubectl -n kube-system kustomize deploy/kubernetes/snapshot-controller | kubectl create -f -

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# install nfs csi driver
helm repo add csi-driver-nfs https://raw.githubusercontent.com/kubernetes-csi/csi-driver-nfs/master/charts
helm install \
  csi-driver-nfs \
  csi-driver-nfs/csi-driver-nfs \
  --namespace kube-system \
  --version v4.6.0

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# install synology csi driver. 
cd ${SCRIPT_DIR}
rm -rf synology-csi
git clone -b v1.1.3 https://github.com/SynologyOpenSource/synology-csi.git synology-csi
sed -ie 's/ --short//' synology-csi/scripts/deploy.sh
cp ${CONFIG_DIR}/synology/synology-client-info.yml \
   synology-csi/config/client-info.yml
rm synology-csi/deploy/kubernetes/v1.20/storage-class.yml
cp ${CONFIG_DIR}/synology/*.yaml \
   synology-csi/deploy/kubernetes/v1.20/
rm synology-csi/deploy/kubernetes/v1.20/namespace.yml
./synology-csi/scripts/deploy.sh install --basic
#sh synology-csi/scripts/deploy.sh install --all

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
  --version 6.2.5 \
  -f argo-cd.values.yaml
sleep 10 &
wait
kubectl wait --namespace argo-cd \
  --for=condition=ready \
  --all pods \
  --timeout=600s
# echo $(kubectl -n argo-cd get secret/argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d) > ${CONFIG_DIR}/argo-cd-default-pw.txt
