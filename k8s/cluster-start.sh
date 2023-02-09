#!/bin/bash
# start tidb in k8s
set -ex

export KUBECTL="kubectl"
export TIDBOP_VERSION="v1.4.2"
export TIDBOP_CRD_VERSION="e9876f702a8cabd20e49027e26df1daefebf1054"
export CHAOS_VERSION="2.3.0"
export NAMESPACE="testing"
export HELM=helm

# pass something to init
if [ -n "$1" ]; then
	$HELM repo add pingcap https://charts.pingcap.org/ || true
	$HELM repo add chaos-mesh https://charts.chaos-mesh.org/ || true
	$HELM repo update
	$KUBECTL create -f https://raw.githubusercontent.com/pingcap/tidb-operator/$TIDBOP_CRD_VERSION/manifests/crd.yaml || $KUBECTL replace -f https://raw.githubusercontent.com/pingcap/tidb-operator/$TIDBOP_CRD_VERSION/manifests/crd.yaml || true
fi

$KUBECTL delete --force namespace $NAMESPACE || true
$KUBECTL create namespace $NAMESPACE || true
$KUBECTL create secret generic basic-sess --namespace=$NAMESPACE --from-file=crt=cert.pem --from-file=key=key.pem
$HELM install operator pingcap/tidb-operator --namespace $NAMESPACE --version $TIDBOP_VERSION --set "operatorImage=xhebox/tidb-operator:latest,imagePullPolicy=Always"
#$HELM install chaos chaos-mesh/chaos-mesh --namespace $NAMESPACE --version $CHAOS_VERSION
$KUBECTL apply -n $NAMESPACE -f ./cluster.yaml
$KUBECTL apply -n $NAMESPACE -f ./monitor.yaml
$KUBECTL apply -n $NAMESPACE -f ./dashboard.yaml
$KUBECTL apply -n $NAMESPACE -f ./debug-proxy.yaml
