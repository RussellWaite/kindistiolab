
#---------------------------------------------------------------------------------------
# download istio if required (the script at getlatestistio checks for ISTIO_VERSION env and picks that one if present, else latest)
[ ! -d "./$ISTIO_FOLDER" ] && curl -L https://git.io/getLatestIstio | sh -

# this repeadedly calls a command until it sees the desired output
#until my_cmd | grep -m 1 "String Im Looking For"; do : ; done

# this would just sit and wait, watching the output
#watch -e "! my_cmd | grep -m 1 \"String Im Looking For\""

# install istio - without helm (seems pointless now as helm's being installed a little later on...)
echo "Waiting for Istio to be downloaded..."
until [ -d "$ISTIO_FOLDER" ]; do sleep 1; done

# CRDs for istio
for i in $ISTIO_FOLDER/install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done

kubectl label namespace default istio-injection=enabled

# gets slow from here on in - potentially (see pull-images.sh) downloading ALOT
# istio install demo setup but without mTLS - damn near everything turned on...
kubectl apply -f $ISTIO_FOLDER/install/kubernetes/istio-demo.yaml

# setup some env vars that might become useful
INGRESS_HOST=$(kubectl get po -l istio=ingressgateway -n istio-system -o jsonpath='{.items[0].status.hostIP}' )
export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
export SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
export GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

echo "\nAbout to setup the following port forwarding..."
echo "kubectl port-forward -n istio-system svc/kiali $KIALI_PORT:20001 --address $PORT_FWD_IP &"
echo "kubectl port-forward -n istio-system svc/grafana $GRAFANA_PORT:3000 --address $PORT_FWD_IP &"
echo "kubectl port-forward -n istio-system svc/prometheus $PROMETHEUS_PORT:9090 --address $PORT_FWD_IP &"
echo "kubectl port-forward -n istio-system svc/tracing $JAEGER_PORT:80 --address $PORT_FWD_IP &"

# setup port forwarding for istio tools kiali, prometheus, grafana, jaegar - MASSIVELY insecure thanks to me binding to all IPS using 0.0.0.0
# you'll need to allow these ports through if you want to go out of the bow - sudo ufw allow <port> e.g. sudo ufw allow 20001
echo "\nWaiting for Kiali pod to be ready..."
until kubectl get pod -l app=kiali -n istio-system | grep -m 1 "Running"; do sleep 1 ; done
kubectl port-forward -n istio-system svc/kiali $KIALI_PORT:20001 --address $PORT_FWD_IP &

echo "Waiting for Grafana pod to be ready..."
until kubectl get pod -l app=grafana -n istio-system | grep -m 1 "Running"; do sleep 1 ; done
kubectl port-forward -n istio-system svc/grafana $GRAFANA_PORT:3000 --address $PORT_FWD_IP &

echo "Waiting for Prometheus pod to be ready..."
until kubectl get pod -l app=prometheus -n istio-system | grep -m 1 "Running"; do sleep 1 ; done
kubectl port-forward -n istio-system svc/prometheus $PROMETHEUS_PORT:9090 --address $PORT_FWD_IP &

echo "Waiting for Jaeger/Tracing pod to be ready..."
until kubectl get pod -l app=jaeger -n istio-system | grep -m 1 "Running"; do sleep 1 ; done
kubectl port-forward -n istio-system svc/tracing $JAEGER_PORT:80 --address $PORT_FWD_IP &

if [ $SHOULD_INSTALL_ISTIO_DEMO -eq 1 ]; then
    # install istio bookinfo demo
    kubectl apply -f $ISTIO_FOLDER/samples/bookinfo/platform/kube/bookinfo.yaml
    kubectl apply -f $ISTIO_FOLDER/samples/bookinfo/networking/bookinfo-gateway.yaml
fi