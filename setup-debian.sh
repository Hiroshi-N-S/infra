#!/bin/bash
set -eux

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# proxyを設定する
export http_proxy=
export https_proxy=
export ftp_proxy=
export no_proxy=

cat <<EOF >env-proxy.sh
export http_proxy=$http_proxy
export https_proxy=$https_proxy
export ftp_proxy=$ftp_proxy
export no_proxy=$no_proxy

export HTTP_PROXY=$http_proxy
export HTTPS_PROXY=$https_proxy
export FTP_PROXY=$ftp_proxy
export NO_PROXY=$no_proxy
EOF
sudo mkdir -p /etc/profile.d
sudo mv env-proxy.sh /etc/profile.d/env-proxy.sh

# aptのproxyを設定する
cat <<EOF >apt-proxy.conf
Acquire::http::Proxy "$http_proxy";
Acquire::https::Proxy "$https_proxy";
EOF
sudo mkdir -p /etc/apt/apt.conf.d
sudo mv apt-proxy.conf /etc/apt/apt.conf.d/apt-proxy.conf

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# システムを初期設定する
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y
sudo apt autoclean

# ロケールを設定する
sudo timedatectl set-timezone Asia/Tokyo
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

sudo apt install -y \
  language-pack-en \
  locales
sudo dpkg-reconfigure -f noninteractive locales
sudo locale-gen en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# ssh-severをインストールする
sudo apt update
sudo apt install -y openssh-server

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# Dockerをインストールする
## 必要パッケージをインストールする
sudo apt update
sudo apt install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

## 公式GPGキーを取得する
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

## リポジトリを登録する
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

## Dockerをインストールする
sudo apt update
sudo apt install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-compose-plugin

sudo chown root:docker /var/run/docker.sock
sudo chmod 660 /var/run/docker.sock

# proxyを設定する
cat <<EOF >docker-proxy.conf
[Service]
Environment="HTTP_PROXY=$http_proxy"
Environment="HTTPS_PROXY=$https_proxy"
EOF
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo mv docker-proxy.conf /etc/systemd/system/docker.service.d/docker-proxy.conf

# HTTPを許可するホストを追加する
cat <<EOF >daemon.json
{
  "insecure-registries": [
    "mysticstorage.local:8443"
  ]
}
EOF
sudo mv daemon.json /etc/docker/daemon.json
sudo systemctl daemon-reload

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# kindをインストールする
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
sudo chown root:root ./kind
sudo chmod a+x ./kind
sudo mv ./kind /usr/local/bin/kind

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# kubectlをインストールする
## 必要パッケージをインストールする
sudo apt update
sudo apt install -y \
  apt-transport-https \
  gnupg2 \
  curl

## 公式GPGキーを取得する
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list

## kubectlをインストールする
sudo apt update
sudo apt install -y kubectl

# --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---
# helmをインストールする
## 必要パッケージをインストールする
sudo apt update
sudo apt install -y \
  apt-transport-https \
  curl

## 公式GPGキーを取得する
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

## helmをインストールする
sudo apt update
sudo apt install -y helm
