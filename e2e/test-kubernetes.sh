#!/bin/bash

management_pod_name=$(kubectl get pods | grep management | head -1 | cut -d ' ' -f 1)
curr_password=$(kubectl logs ${management_pod_name} | grep Password | cut -d ':' -f 2 | sed 's/ //')
kubectl cp test-remote-ssh-kube.sh ${management_pod_name}:/tmp/
kubectl exec ${management_pod_name} -- /bin/bash -c "/tmp/test-remote-ssh-kube.sh $curr_password ${management_pod_name}"
res=$?
if [ $res -eq 0 ]; then
	echo "Kubernetes Test PASSED"
else
	echo "Kubernetes Test FAILED"
	exit 1
fi
