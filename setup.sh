#! zsh

ISTIO_VERSION="1.2.2"

ISTIO_FOLDER="istio-$ISTIO_VERSION"

kind delete cluster --name kind

kind create cluster --config ./one_worker.yaml

[[ ! -d "./$ISTIO_FOLDER" ]] && curl -L https://git.io/getLatestIstio | sh -

