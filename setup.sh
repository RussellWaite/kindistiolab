#! zsh

export ISTIO_VERSION="1.2.2"

export ISTIO_FOLDER="istio-$ISTIO_VERSION"

kind delete cluster --name kind

kind create cluster --config ./one_worker.yaml

export KUBECONFIG="$(kind get kubeconfig-path --name="kind")"
kubectl cluster-info

# download istio if required
[[ ! -d "./$ISTIO_FOLDER" ]] && curl -L https://git.io/getLatestIstio | sh -


# install istio - without helm
cd $ISTIO_FOLDER
# CRDs for istio
for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done

kubectl label namespace default istio-injection=enabled

#gets slow from here on in - downloading ALOT - TODO: need to look at storing and retrieving from local docker store/forcing images into Kind

# istio install demo setup but without mTLS - damn near everything turned on...
kubectl apply -f install/kubernetes/istio-demo.yaml

# setup some env vars that might become useful
read INGRESS_HOST <<<$( kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}' )
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

#setup port forwarding for istio tools kiali, prometheus, grafana, jaegar
kubectl port-forward -n istio-system svc/kiali 20001:20001 &
kubectl port-forward -n istio-system svc/grafana 3000:3000 &
kubectl port-forward -n istio-system svc/prometheus 9090:9090 &
kubectl port-forward -n istio-system svc/tracing 10080:80 &

#install bookinfo demo
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml

# install helm into the cluster (I'm not a fan but it makes things a bit easier for now)
# this needs the helm client installed locally...
kubectl -n kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'      
helm init --service-account tiller --upgrade

# create openfaas namespaces (just running something fresh from the internet in my local cluster, no reason to ... PANIC!!!)
kubectl apply -f https://raw.githubusercontent.com/openfaas/faas-netes/master/namespaces.yml
kubectl get namespaces --show-labels

# and again - install blind from internet - HELM - magic... (oh, this is openfaas install by the way)
helm repo add openfaas https://openfaas.github.io/faas-netes/
export OF_PASSWORD=$(head -c 12 /dev/urandom | shasum| cut -d' ' -f1)
kubectl -n openfaas create secret generic basic-auth --from-literal=basic-auth-user=admin --from-literal=basic-auth-password="$OF_PASSWORD"
helm repo update
helm upgrade openfaas --install openfaas/openfaas --namespace openfaas --set basic_auth=true --set functionNamespace=openfaas-fn
