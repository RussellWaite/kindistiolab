[ ! -d "./$LINKERD_FOLDER" ] && 
    mkdir $LINKERD_FOLDER && 
    curl -L https://github.com/linkerd/linkerd2/releases/download/stable-$LINKERD_VERSION/linkerd2-cli-stable-$LINKERD_VERSION-linux --output linkerd_install_cli.sh && 
    curl -L && sh $LINKERD_FOLDER/linkerd_install_client.sh
    
PATH = $PATH:$HOME/.linkerd2/bin

echo "Linkerd 2 version... $(linkerd version)"

linkerd check --pre

linkerd install | kubectl apply -f -

linkerd check

kubectl -n linkerd get deploy

linkerd dashboard &

  
if [ $SHOULD_INSTALL_LINKERD_DEMO -eq 1 ]; then
    curl -sL https://run.linkerd.io/emojivoto.yml | kubectl apply -f -
    
    kubectl -n emojivoto port-forward svc/web-svc 8080:80 &

    kubectl get -n emojivoto deploy -o yaml | linkerd inject - | kubectl apply -f -
fi