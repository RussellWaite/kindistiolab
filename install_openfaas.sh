#---------------------------------------------------------------------------------------
# create openfaas namespaces (just running something fresh from the internet in my local cluster, no reason to ... PANIC!!!)
kubectl apply -f https://raw.githubusercontent.com/openfaas/faas-netes/master/namespaces.yml
kubectl get namespaces --show-labels

# and again - install blind from internet - HELM - magic... (oh, this is openfaas install by the way)
helm repo add openfaas https://openfaas.github.io/faas-netes/
export OF_PASSWORD=$(head -c 12 /dev/urandom | shasum| cut -d' ' -f1)
echo "If using OpenFaaS, this might come in handy $OF_PASSWORD"
kubectl -n openfaas create secret generic basic-auth --from-literal=basic-auth-user=admin --from-literal=basic-auth-password="$OF_PASSWORD"
helm repo update

echo "Waiting for tiller pod to come online..."
until kubectl get pod -l app=helm -l name=tiller -n kube-system | grep -m 1 "1/1"; do sleep 1 ; done
helm upgrade openfaas --install openfaas/openfaas --namespace openfaas --set basic_auth=true --set functionNamespace=openfaas-fn --set "faasnetes.imagePullPolicy=IfNotPresent"

kubectl --namespace=openfaas get deployments -l "release=openfaas, app=openfaas"
kubectl get svc -n openfaas gateway-external -o wide

echo "Waiting for openfaas pod to come online..."
until kubectl get pod -n openfaas -l app=gateway | grep -m 1 "Running"; do sleep 1 ; done
kubectl port-forward -n openfaas svc/gateway $OPENFAAS_PORT:8080 --address $PORT_FWD_IP 2>/dev/null &