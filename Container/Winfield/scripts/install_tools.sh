#!/bin/bash

# Update and install system tools.
apt-get update
apt-get upgrade
apt-get install -y build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev pkg-config nano curl jq

# Install python.
mkdir -p ~/downloads
cd ~/downloads
python_version=$(jq -r '.python' tools.json)
wget https://www.python.org/ftp/python/${python_version}/Python-${python_version}.tgz
tar -xf Python-${python_version}.tgz
rm Python-${python_version}.tgz
cd Python-${python_version}
./configure --enable-optimizations
make -j$(nproc)
make altinstall
echo "alias python=\"/usr/local/bin/python3.11\"" >> ~/.bashrc
source ~/.bashrc
cd ~/downloads
/usr/local/bin/python3.11 -m pip install requests
rm -r Python-${python_version}

# Install helm and kubectl.
helm_version=$(jq -r '.helm' tools.json)
kubectl_version=$(jq -r '.kubectl' tools.json)
operating_system=linux
mkdir -p ~/.azure/kubectl-client/
curl -LO https://storage.googleapis.com/kubernetes-release/release/${kubectl_version}/bin/${operating_system}/amd64/kubectl
install -o root -g root -m 0755 kubectl ~/.azure/kubectl-client/
rm kubectl
curl -LO https://k8connecthelm.azureedge.net/helm/helm-${helm_version}-${operating_system}-amd64.tar.gz
tar -xzf helm-${helm_version}-${operating_system}-amd64.tar.gz
rm helm-${helm_version}-${operating_system}-amd64.tar.gz
mkdir -p ~/.azure/helm/${helm_version}/${operating_system}-amd64/
mv linux-amd64/helm ~/.azure/helm/${helm_version}/${operating_system}-amd64/
rm -r ${operating_system}-amd64
mkdir -p ~/.kube

# Update environment variables.
echo "export PATH=\"$PATH:/root/.azure/kubectl-client/:/root/.azure/helm/${helm_version}/linux-amd64/\"" >> ~/.bashrc
echo "export REQUESTS_CA_BUNDLE=\"/etc/ssl/certs/ca-certificates.crt\"" >> ~/.bashrc
echo "export AZURE_CORE_INSTANCE_DISCOVERY=false" >> ~/.bashrc
echo "export HELM_CLIENT_PATH=\"/root/.azure/helm/${helm_version}/linux-amd64/helm\"" >> ~/.bashrc
source ~/.bashrc

# Install Azure CLI.
apt-get install -y apt-transport-https ca-certificates gnupg lsb-release
mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
chmod go+r /etc/apt/keyrings/microsoft.gpg
AZ_DIST=$(lsb_release -cs)
echo "Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: ${AZ_DIST}
Components: main
Architectures: $(dpkg --print-architecture)
Signed-by: /etc/apt/keyrings/microsoft.gpg" | tee /etc/apt/sources.list.d/azure-cli.sources
apt-get update
AZ_DIST=$(lsb_release -cs)
AZ_VER=$(jq -r '.azureCliVersion' tools.json)
apt-get install -y azure-cli=${AZ_VER}-1~${AZ_DIST}

# Install Azure CLI extensions.
az extension add -y --name aksarc --version $(jq -r '.azureCliExtensions.public.aksarc' tools.json)
az extension add -y --source $(jq -r '.azureCliExtensions.private.connectedk8s' tools.json)
az extension add -y --name connectedmachine --version $(jq -r '.azureCliExtensions.public.connectedmachine' tools.json)
az extension add -y --name customlocation --version $(jq -r '.azureCliExtensions.public.customlocation' tools.json)
az extension add -y --name guestconfig --version $(jq -r '.azureCliExtensions.public.guestconfig' tools.json)
az extension add -y --name k8s-extension --version $(jq -r '.azureCliExtensions.public."k8s-extension"' tools.json)
az extension add -y --name k8s-configuration --version $(jq -r '.azureCliExtensions.public."k8s-configuration"' tools.json)
az extension add -y --name stack-hci-vm --version $(jq -r '.azureCliExtensions.public."stack-hci-vm"' tools.json)
