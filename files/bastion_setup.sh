#!/bin/bash
set -e

sudo yum update -y
sudo yum install git jq unzip -y

# Install AWS CLI

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Install kubectl

curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl | bash
sudo mv kubectl /usr/local/bin/
sudo chmod +x /usr/local/bin/kubectl

# Install helm

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash
chmod 700 get_helm.sh
./get_helm.sh

# Verify installs
aws --version
kubectl version --client
helm version

