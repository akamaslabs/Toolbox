#!/bin/bash

# $1: KUBE_CLUSTER
# $2: NAMESPACE

aws eks --region 'us-east-2' update-kubeconfig --name "$1"
kubectl config set-context --current --namespace=$2
management_pod_name=$(kubectl get pods | grep management | head -1 | cut -d ' ' -f 1)
curr_password=$(kubectl logs ${management_pod_name} 2>/dev/null | grep -i 'You can ssh into this container' | grep -o "'[^']*'" | sed -n '2p' | tr -d "'\n")
kubectl cp test-remote-ssh.sh ${2}/${management_pod_name}:/tmp/
kubectl exec ${management_pod_name} -- /bin/bash -c "/tmp/test-remote-ssh.sh $curr_password management-pod"
res=$?
if [ $res -eq 0 ]; then
	echo "Kubernetes Test PASSED"
else
	echo "Kubernetes Test FAILED"
	exit 1
fi
