#!/bin/bash
# start tidb in the operator
set -ex

export KUBECTL="kubecel"
export TIDBOP_VERSION="v1.3.7"
export CHAOS_VERSION="2.3.0"
export NAMESPACE="testing"
export HELM=helm

# pass something to init
if [ -n "$1" ]; then
	$HELM repo add pingcap https://charts.pingcap.org/ || true
	$HELM repo add chaos-mesh https://charts.chaos-mesh.org/ || true
	$KUBECTL create -f https://raw.githubusercontent.com/pingcap/tidb-operator/$TIDBOP_VERSION/manifests/crd.yaml || true
	$HELM repo update
fi

$KUBECTL delete namespace $NAMESPACE || true
$KUBECTL create namespace $NAMESPACE || true
$HELM install operator pingcap/tidb-operator --namespace $NAMESPACE --version $TIDBOP_VERSION
$HELM install cluster pingcap/tidb-cluster --namespace $NAMESPACE --version $TIDBOP_VERSION --set \
  "schedulerName=default-scheduler,pd.storageClassName=standard,tikv.storageClassName=standard,pd.replicas=1,tikv.replicas=1,tidb.replicas=1"
$HELM install chaos chaos-mesh/chaos-mesh --namespace $NAMESPACE --version $CHAOS_VERSION
