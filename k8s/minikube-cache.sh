#!/bin/bash
# cache images that may not be cached by minikube

set -ex
export KUBECTL=kubectl
export JQ=jq
list=$($KUBECTL get pods --all-namespaces -o json | $JQ -r '(.items[].spec | select(.initContainers != null) | .initContainers[].image)' | sort | uniq)
for i in $list; do
	minikube image load $i
done
