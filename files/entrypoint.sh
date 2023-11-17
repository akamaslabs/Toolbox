#!/bin/bash

WORK_FLD=/work
DBG="${DBG:-false}"
USER="${USER:-$(whoami)}"
#########################
# Functions
#########################

dbg () {
  [ "$DBG" != 'false' ] && echo "DEBUG: $1"
}

initialize_credentials () {
  dbg 'Initializing credentials'
  mkdir -p "${HOME}/.ssh" "${HOME}/.sshd"
  [ ! -f "${HOME}/.ssh/password" ] && echo $RANDOM | md5sum | head -c 20 > "${HOME}/.ssh/password"
  [ ! -f "${HOME}/.ssh/id_rsa" ] && \
    ssh-keygen -q -f "${HOME}/.ssh/id_rsa" -N '' -t rsa -b 2048 && \
    cp "${HOME}/.ssh/id_rsa.pub" "${HOME}/.ssh/authorized_keys"
  [ ! -f "${HOME}/.sshd/ssh_host_rsa_key" ] && cat "${HOME}/.ssh/password" | ssh-keygen -q -f "${HOME}/.sshd/ssh_host_rsa_key" -N '' -t rsa
  [ ! -f "${HOME}/.sshd/ssh_host_dsa_key" ] && cat "${HOME}/.ssh/password" | ssh-keygen -q -f "${HOME}/.sshd/ssh_host_dsa_key" -N '' -t dsa
  chmod 400 ${HOME}/.ssh/* ${HOME}/.sshd/*
  echo "Credentials initialized"
}

update_password () {
  # use passwd and not chpassw since we need to run it as non-sudo
  dbg "Updating password with $1"
  echo -e "$(cat ${HOME}/.ssh/def_pwd)\n$1\n$1" | passwd > /dev/null

  if [ $? -ne 0 ] ; then
    echo "ERROR: unable to update ${USER} password"
    exit 1
  else
    echo Updated $USER user password
  fi
}

#########################
# Main
#########################

if [ -z "${KUBERNETES_SERVICE_HOST}" ]; then
  # Initialize keys for DOCKER
  # No need for KUBE, secrets provided through secrets
  initialize_credentials
fi

PASS="$(cat ${HOME}/.ssh/password)"

if [ -f "${HOME}/.ssh/def_pwd" ] ; then
  dbg 'Default password found'
  # Update default password with the random one
  update_password "$PASS"
  dbg 'Removing default password'
  rm -f "${HOME}/.ssh/def_pwd"   # delete, to avoid re-running on next docker restart
fi

# If can sudo
if echo "$PASS" | sudo -S -v ; then
  dbg 'Try to own work folder'
  echo "$PASS" | sudo -S chown "$USER:$USER" "${WORK_FLD}"
  [ -d "${WORK_FLD}/.kube" ] && echo "$PASS" | sudo -S chown "$USER:$USER" "${WORK_FLD}/.kube"
else
  echo WARNING: cannot run as privileged user
fi

# Check we can write into /work
touch "$WORK_FLD/.canary"
[ $? -ne 0 ] && echo WARNING: Unable to write on the volume mounted on $WORK_FLD. Manually fix your configurations to ensure the persistence of your artifacts.
rm -f "$WORK_FLD/.canary"

mkdir -p "${WORK_FLD}/.kube" && \
ln -s "${WORK_FLD}/.kube" "${HOME}/.kube"

echo "Container started" 1>&2
echo "You can ssh into this container with user 'akamas' and password '$PASS'" 1>&2

# Start sshd
if [ -n "${KUBERNETES_SERVICE_HOST}" ]; then
  # Set k8s startup probe
  echo started > /tmp/healthcheck
  /usr/sbin/sshd -p 2222 -D \
    -h "${HOME}/.sshd/ssh_host_rsa_key" \
    -h "${HOME}/.sshd/ssh_host_dsa_key" \
    -o "PidFile ${HOME}/.sshd/sshd.pid" -e |& tee -a "${HOME}/sshd.log"
else
  echo "$PASS" | sudo -S /usr/sbin/sshd -D \
    -h "${HOME}/.sshd/ssh_host_rsa_key" \
    -h "${HOME}/.sshd/ssh_host_dsa_key" -e |& tee -a "${HOME}/sshd.log"
fi

echo SSHD exited
sleep 5