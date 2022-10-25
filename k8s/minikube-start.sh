#!/bin/bash
# start a k8s cluster locally 

set -ex

# pass something to delete the old k8s cluster
if [ "$1" != "" ]; then
	minikube delete --all
fi

minikube start --driver=docker --image-mirror-country cn \
	--extra-config=kubelet.eviction-hard='memory.available<10Mi' --extra-config=kubelet.eviction-minimum-reclaim='memory.available=0Gi' --extra-config=kubelet.kube-reserved='memory=100Mi' --extra-config=kubelet.system-reserved='memory=100Mi'
