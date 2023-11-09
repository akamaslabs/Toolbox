#!/bin/bash

WORK_FLD=/work
PERSISTENCE_FLD=${WORK_FLD}/.akamas_keys

DEF_PASS="$(cat ${HOME}/.ssh/def_pwd)"

# Try to own work folder
if echo "$DEF_PASS" | sudo -S -v ; then
	echo "$DEF_PASS" | sudo -S chown "$USER:$USER" $WORK_FLD
	[ -d $WORK_FLD/.kube ] && echo "$DEF_PASS" | sudo -S chown "$USER:$USER" $WORK_FLD/.kube
else
	echo WARNING: cannot run as privileged user
fi

if [ -n "${KUBERNETES_SERVICE_HOST}" ]; then
	# KUBE
	# Credentials provided natively by the chart, no need to initialize
	# Warn user for permission issues need
	touch "$WORK_FLD/.canary"
	[ $? -ne 0 ] && echo WARNING: Unable to write on the volume mounted on $WORK_FLD. Manually fix your configurations to ensure the persistence of your artifacts.
	rm "$WORK_FLD/.canary"

else
	# DOCKER
	# Initialize keys under persisted volume
	mkdir -p "$PERSISTENCE_FLD"
	[ $? -ne 0 ] && echo ERROR: Unable to write in the work directory $WORK_FLD. && exit 1

	# Create persisted credentials
	[ -f "$PERSISTENCE_FLD/password" ] || echo $RANDOM | md5sum | head -c 20 > "$PERSISTENCE_FLD/password"
	[ -f "$PERSISTENCE_FLD/id_rsa" ] || ssh-keygen -q -f "$PERSISTENCE_FLD/id_rsa" -N '' -t rsa -b 2048
	[ -f "$PERSISTENCE_FLD/ssh_host_rsa_key" ] || cat "$PERSISTENCE_FLD/password" | ssh-keygen -q -f "$PERSISTENCE_FLD/ssh_host_rsa_key" -N '' -t rsa
	[ -f "$PERSISTENCE_FLD/ssh_host_dsa_key" ] || cat "$PERSISTENCE_FLD/password" | ssh-keygen -q -f "$PERSISTENCE_FLD/ssh_host_dsa_key" -N '' -t dsa

	# Copy into home folder
	mkdir -p "${HOME}/.ssh" "${HOME}/.sshd"
	cp "$PERSISTENCE_FLD/password" "${HOME}/.ssh/"
	cp "$PERSISTENCE_FLD/id_rsa" "${HOME}/.ssh/"
	cp "$PERSISTENCE_FLD/id_rsa.pub" "${HOME}/.ssh/"
	cp "$PERSISTENCE_FLD/id_rsa.pub" "${HOME}/.ssh/authorized_keys"
	cp "$PERSISTENCE_FLD/ssh_host_rsa_key" "${HOME}/.sshd/"
	cp "$PERSISTENCE_FLD/ssh_host_dsa_key" "${HOME}/.sshd/"

	echo "Credentials initialized"
fi

# Back to the common section

mkdir -p /work/.kube && \
ln -s /work/.kube ${HOME}/.kube

# Update default password with the random one
PASS="$(cat ${HOME}/.ssh/password)"
echo -e "${DEF_PASS}\n${PASS}\n${PASS}" | passwd > /dev/null
[ $? -ne 0 ] && echo ERROR: unable to update $USER password && exit 1
rm ${HOME}/.ssh/def_pwd
echo Updated $USER user password

# Set k8s startup probe
[ -n "${KUBERNETES_SERVICE_HOST}" ] && echo started > /tmp/healthcheck
echo "Container started" 1>&2
echo "You can ssh into this container with user 'akamas' and password '$PASS'" 1>&2

# Start sshd
if [ -n "${KUBERNETES_SERVICE_HOST}" ]; then
	/usr/sbin/sshd -p 2222 -D \
		-h ${HOME}/.sshd/ssh_host_rsa_key \
		-h ${HOME}/.sshd/ssh_host_dsa_key \
		-o "PidFile ${HOME}/.sshd/sshd.pid" |& tee ${HOME}/.sshd/sshd.log
else
	echo "$PASS" | sudo -S /usr/sbin/sshd -D \
		-h ${HOME}/.sshd/ssh_host_rsa_key \
		-h ${HOME}/.sshd/ssh_host_dsa_key |& tee ${HOME}/.sshd/sshd.log
fi

echo SSHD exited
sleep 5