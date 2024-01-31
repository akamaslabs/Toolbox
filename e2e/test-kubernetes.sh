#!/bin/bash

# $1: KUBE_CLUSTER
# $2: NAMESPACE

aws eks --region 'us-east-2' update-kubeconfig --name "$1"
kubectl config set-context --current --namespace="$2"
toolbox_pod_name=$(kubectl get pods -l service=toolbox --no-headers -o custom-columns=':metadata.name')
curr_password="$(kubectl exec deploy/toolbox -- cat /home/akamas/password)"
kubectl cp test-remote-ssh.sh "${2}/${toolbox_pod_name}:/tmp/"
kubectl exec "${toolbox_pod_name}" -- /bin/bash -x -c "/tmp/test-remote-ssh.sh $curr_password toolbox"
res=$?
if [ $res -eq 0 ]; then
	echo "Kubernetes Test PASSED"
else
	echo "Kubernetes Test FAILED"
	exit 1
fi
