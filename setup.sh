# install kind if not present
if ! hash kind 2>/dev/null; then
    GO111MODULE="on" go get sigs.k8s.io/kind@v0.4.0
fi

until command -v kind>/dev/null; do sleep 1 ; done

# clean old cluster then create new one
kind delete cluster --name kind
kind create cluster --config ./one_worker.yaml

export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"
kubectl cluster-info

#---------------------------------------------------------------------------------------
export ISTIO_VERSION="1.2.2"
export ISTIO_FOLDER="istio-$ISTIO_VERSION"

# download istio if required
[[ ! -d "./$ISTIO_FOLDER" ]] && curl -L https://git.io/getLatestIstio | sh -


# this repeadedly calls a command until it sees the desired output
#until my_cmd | grep -m 1 "String Im Looking For"; do : ; done

# this would just sit and wait, watching the output
#watch -e "! my_cmd | grep -m 1 \"String Im Looking For\""

# install istio - without helm (seems pointless now as helm's being installed a little later on...)
until [ -d "$ISTIO_FOLDER" ]; do sleep 1; done

# CRDs for istio
for i in $ISTIO_FOLDER/install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done

# TODO: what to wait on here? do we even need to?

kubectl label namespace default istio-injection=enabled

#gets slow from here on in - downloading ALOT - TODO: need to look at storing and retrieving from local docker store/forcing images into Kind

# istio install demo setup but without mTLS - damn near everything turned on...
kubectl apply -f $ISTIO_FOLDER/install/kubernetes/istio-demo.yaml

# setup some env vars that might become useful
read INGRESS_HOST <<<$( kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}' )
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

export PORT_FWD_IP=0.0.0.0 # 127.0.0.1

#setup port forwarding for istio tools kiali, prometheus, grafana, jaegar - MASSIVELY insecure thanks to me binding to all IPS using 0.0.0.0
# you'll need to allow these ports through if you want to go out of the bow - sudo ufw allow <port> e.g. sudo ufw allow 20001
until kubectl get pod -l app=kiali -n istio-system | grep -m 1 "Running"; do sleep 1 ; done
kubectl port-forward -n istio-system svc/kiali 20001:20001 --address $PORT_FWD_IP &
until kubectl get pod -l app=grafana -n istio-system | grep -m 1 "Running"; do sleep 1 ; done
kubectl port-forward -n istio-system svc/grafana 3000:3000 --address $PORT_FWD_IP &
until kubectl get pod -l app=prometheus -n istio-system | grep -m 1 "Running"; do sleep 1 ; done
kubectl port-forward -n istio-system svc/prometheus 9090:9090 --address $PORT_FWD_IP &
until kubectl get pod -l app=jaeger -n istio-system | grep -m 1 "Running"; do sleep 1 ; done
kubectl port-forward -n istio-system svc/tracing 10080:80 --address $PORT_FWD_IP &

#install istio bookinfo demo
kubectl apply -f $ISTIO_FOLDER/samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply -f $ISTIO_FOLDER/samples/bookinfo/networking/bookinfo-gateway.yaml

#---------------------------------------------------------------------------------------
# install helm into the cluster (I'm not a fan but it makes things a bit easier for now)
# this needs the helm client installed locally...
if ! hash helm 2>/dev/null; then
    export HELM_TAR="helm-v2.14.3-linux-amd64.tar.gz"
    curl https://get.helm.sh/$HELM_TAR --output $HELM_TAR
    tar -zxvf $HELM_TAR
    sudo mv linux-amd64/helm /usr/local/bin/helm
fi
kubectl -n kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
#kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
helm init --service-account tiller --upgrade


#---------------------------------------------------------------------------------------
# create openfaas namespaces (just running something fresh from the internet in my local cluster, no reason to ... PANIC!!!)
kubectl apply -f https://raw.githubusercontent.com/openfaas/faas-netes/master/namespaces.yml
kubectl get namespaces --show-labels

# and again - install blind from internet - HELM - magic... (oh, this is openfaas install by the way)
helm repo add openfaas https://openfaas.github.io/faas-netes/
export OF_PASSWORD=$(head -c 12 /dev/urandom | shasum| cut -d' ' -f1)
kubectl -n openfaas create secret generic basic-auth --from-literal=basic-auth-user=admin --from-literal=basic-auth-password="$OF_PASSWORD"
helm repo update
echo "Waiting for tiller pod to come online..."
until kubectl get pod -l app=helm -l name=tiller -n kube-system | grep -m 1 "1/1"; do sleep 1 ; done
helm upgrade openfaas --install openfaas/openfaas --namespace openfaas --set basic_auth=true --set functionNamespace=openfaas-fn

kubectl --namespace=openfaas get deployments -l "release=openfaas, app=openfaas"
kubectl get svc -n openfaas gateway-external -o wide
echo "Waiting for openfaas pod to come online..."
until kubectl get pod -n openfaas -l app=gateway | grep -m 1 "Running"; do sleep 1 ; done
kubectl port-forward -n openfaas svc/gateway 31112:31112 --address $PORT_FWD_IP 2>/dev/null &

# allowing holes in the hosts firewall so externals can communicate with the port forwarded services 
# here be dragons...
# sudo ufw allow 20001
# sudo ufw allow 3000
# sudo ufw allow 9090
# sudo ufw allow 10080
# sudo ufw allow 31112