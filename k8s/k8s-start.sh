#!/bin/bash
# start tidb in k8s
set -ex

export KUBECTL="kubectl"
export TIDBOP_VERSION="v1.3.7"
export CHAOS_VERSION="2.3.0"
export NAMESPACE="testing"
export HELM=helm

# pass something to init
if [ -n "$1" ]; then
	$HELM repo add pingcap https://charts.pingcap.org/ || true
	$HELM repo add chaos-mesh https://charts.chaos-mesh.org/ || true
	$HELM repo update
	$KUBECTL apply -f https://raw.githubusercontent.com/pingcap/tidb-operator/$TIDBOP_VERSION/manifests/crd.yaml || true
fi

$KUBECTL delete namespace $NAMESPACE
$KUBECTL create namespace $NAMESPACE || true
$HELM install operator pingcap/tidb-operator --namespace $NAMESPACE --version $TIDBOP_VERSION --set "operatorImage=xhebox/operator:latest"
$HELM install chaos chaos-mesh/chaos-mesh --namespace $NAMESPACE --version $CHAOS_VERSION
$KUBECTL apply -f ./cluster.yaml
