# set env vars for usage - this controls external access, port forwarding, and features in cluster
export KIALI_PORT=20001
export GRAFANA_PORT=3000
export PROMETHEUS_PORT=9090
export JAEGER_PORT=10080
export OPENFAAS_PORT=31112

# 0 prevents, 1 allows
#mesh
export SHOULD_INSTALL_ISTIO=0
export SHOULD_INSTALL_ISTIO_DEMO=0
export SHOULD_INSTALL_LINKERD=1
export SHOULD_INSTALL_LINKERD_DEMO=1 

#serverless
export SHOULD_INSTALL_OPENFAAS=0
export SHOULD_INSTALL_OPENFAAS=0

#ohers
export SHOULD_INSTALL_HELM_CLIENT=0
export SHOULD_INSTALL_NATS=0

export SHOULD_ALLOW_EXTERNAL_ACCESS=0

export ISTIO_VERSION="1.4.4"
export ISTIO_FOLDER="istio-$ISTIO_VERSION"

export LINKERD_VERSION="2.7.0"
export LINKERD_FOLDER="linkerd-$LINKERD_VERSION"

export HELM_VERSION="3.1.0"

# external access and firewall hole creation
if (($SHOULD_ALLOW_EXTERNAL_ACCESS)); then
    export PORT_FWD_IP=0.0.0.0
    sudo ufw allow $KIALI_PORT
    sudo ufw allow $GRAFANA_PORT
    sudo ufw allow $PROMETHEUS_PORT
    sudo ufw allow $JAEGER_PORT
    sudo ufw allow $OPENFAAS_PORT
else
    export PORT_FWD_IP=127.0.0.1
    sudo ufw delete allow $KIALI_PORT
    sudo ufw delete allow $GRAFANA_PORT
    sudo ufw delete allow $PROMETHEUS_PORT
    sudo ufw delete allow $JAEGER_PORT
    sudo ufw delete allow $OPENFAAS_PORT
fi

pathadd() {
    if [ -d "$1" ] && [ ":$PATH:" != *":$1:"* ]; then
        PATH="${PATH:+"$PATH:"}$1"
    fi
}

#---------------------------------------------------------------------------------------
# install kind if not present
if ! hash kind 2>/dev/null; then
    GO111MODULE="on" go get sigs.k8s.io/kind@v0.4.0
fi

until command -v kind>/dev/null; do sleep 1 ; done

# clean old cluster then create new one
kind delete cluster --name kind
kind create cluster --config ./one_worker.yaml

#export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"
kubectl cluster-info --context kind-kind
# kind-kind should be set to default context for kubectl - use kubectl config current-context
echo "Current Kubectl context is now..."
kubectl config current-context

echo "\nGet all locally cached images 🗃"

# side load locally cached images (saves external network traffic)
./kind_load_images.sh
echo "\n"

if [ $SHOULD_INSTALL_ISTIO -eq 1 ]; then
    ./install_istio.sh
fi

if [ $SHOULD_INSTALL_LINKERD -eq 1 ]; then
    ./install_linkerd.sh
fi

if [ $SHOULD_INSTALL_HELM_CLIENT -eq 1 ]; then
    #---------------------------------------------------------------------------------------
    # install helm into the cluster (I'm not a fan but it makes things a bit easier for now)
    # this needs the helm client installed locally...
    if ! hash helm 2>/dev/null; then        
        HELM_TAR="helm.tar.gz"
        curl https://get.helm.sh/helm-v$(HELM_VERSION)-linux-amd64.tar.gz --output $HELM_TAR
        tar -zxvf $HELM_TAR
        sudo mv linux-amd64/helm /usr/local/bin/helm
        helm repo add stable https://kubernetes-charts.storage.googleapis.com/
        echo "Helm version... $(helm version)"
    fi
    helm repo update
fi

if [ $SHOULD_INSTALL_OPENFAAS -eq 1 ]; then
    ./install_openfaas.sh
fi

if [ $SHOULD_INSTALL_NATS -eq 1 ]; then
    echo "Installing NATS"
    kubectl create ns nats-io
    kubectl apply -f ./nats/00-prereqs.yaml
    kubectl apply -f ./nats/10-deployment.yaml
    echo "Confirming NATS installed"
    kubectl get crd
fi
