#!/bin/bash

WORK_FLD=/work
DBG="${DBG:-false}"
USER="${USER:-$(whoami)}"
ALLOW_PASSWORD="${ALLOW_PASSWORD:-false}"
USE_PAM="${USE_PAM:-yes}"
DEBUG_LEVEL=${DEBUG_LEVEL:0}

#########################
# Functions
#########################

initialize_credentials () {
  echo 'Initializing credentials'
  mkdir -p "${HOME}/.ssh" "${HOME}/.sshd"
  if [ ! -f "${HOME}/.ssh/password" ] ; then
    if [ -n "${CUSTOM_PASSWORD}" ]; then
      echo "Password file not found, will store the configured one."
      echo "${CUSTOM_PASSWORD}" > "${HOME}/.ssh/password"
    else
      echo "Password file not found, will generate a new random one."
      echo $RANDOM | md5sum | head -c 20 > "${HOME}/.ssh/password"
    fi
  fi

  if [ ! -f "${HOME}/.ssh/id_rsa" ] ; then
    echo "Private key file not found, will generate a new one."
    ssh-keygen -q -f "${HOME}/.ssh/id_rsa" -N '' -t rsa -b 2048 && \
    cp "${HOME}/.ssh/id_rsa.pub" "${HOME}/.ssh/authorized_keys"
  fi

  if [ ! -f "${HOME}/.sshd/ssh_host_rsa_key" ] ; then
    echo "Host rsa key file not found, will generate a new one."
    ssh-keygen -q -f "${HOME}/.sshd/ssh_host_rsa_key" -N '' -t rsa
  fi
  if [ ! -f "${HOME}/.sshd/ssh_host_dsa_key" ] ; then
   echo "Host dsa key file not found, will generate a new one."
   ssh-keygen -q -f "${HOME}/.sshd/ssh_host_dsa_key" -N '' -t dsa
  fi

  chmod 400 "${HOME}"/.ssh/* "${HOME}"/.sshd/*
  echo "Credentials initialized"
}

update_password () {
  # use passwd and not chpassw since we need to run it as non-sudo
  echo -e "$(cat "${HOME}/.factory_password")\n${PASS}\n${PASS}" | passwd > /dev/null

  if [ "$?" -ne 0 ] ; then
    echo "ERROR: unable to update the password for user ${USER}. Keeping the default one."
    PASS=$(cat "${HOME}/.factory_password")
  else
    echo "Updated $USER user password"
    rm -f "${HOME}/.factory_password"
  fi
}

adjust_docker_gid () {
  # Adjust docker group GID to match the mounted socket's GID
  # This allows the container to work on any host regardless of its docker GID
  if [ -S /var/run/docker.sock ]; then
    SOCKET_GID=$(stat -c '%g' /var/run/docker.sock)
    CURRENT_GID=$(getent group docker | cut -d: -f3)
    if [ "$SOCKET_GID" != "$CURRENT_GID" ]; then
      # Check if another group already uses the target GID.
      # Safe to delete: these are typically system groups (e.g., systemd-journal)
      # that aren't needed in this container's context.
      CONFLICTING_GROUP=$(getent group "$SOCKET_GID" | cut -d: -f1)
      if [ -n "$CONFLICTING_GROUP" ]; then
        echo "Removing conflicting group '$CONFLICTING_GROUP' that uses GID $SOCKET_GID"
        echo "$PASS" | sudo -S groupdel "$CONFLICTING_GROUP"
      fi
      echo "Adjusting docker group GID from $CURRENT_GID to $SOCKET_GID"
      echo "$PASS" | sudo -S groupmod -g "$SOCKET_GID" docker
    fi
  fi
}

#########################
# Main
#########################
echo "Starting Managment pod"
test -f "${HOME}/.ssh/password"
GENERATED_PASSWORD_EXISTS=$?
test -f "${HOME}/.factory_password"
DEFAULT_PASSWORD_EXISTS=$?


if [ "$DBG" != 'false' ] ; then
  date
  echo "Env:"
  env
  echo "ALLOW_PASSWORD: $ALLOW_PASSWORD"

  echo "Home content:"
  find ~ -ls
  echo "Workdir content"
  find "$WORK_FLD" -ls
  echo "Generated password exists: $GENERATED_PASSWORD_EXISTS"
  echo "Default password exists: $DEFAULT_PASSWORD_EXISTS"
fi


if [[ -z "${KUBERNETES_SERVICE_HOST}" ]] && [[ "$GENERATED_PASSWORD_EXISTS" -eq 1 ]]; then
  # Initialize keys for DOCKER if not already initialized
  # No need for KUBE, secrets provided through secrets
  initialize_credentials
fi

if [ "$DBG" != 'false' ] ; then
  echo "Home content after credentials initialization:"
  find ~ -ls
fi

PASS="$(cat "${HOME}/.ssh/password")"

if [ "$DEFAULT_PASSWORD_EXISTS" -eq 0 ] ; then
  echo 'Default password found, updating it.'
  # Update default password with the random one
  update_password "$PASS"
fi

if [ "$DBG" != 'false' ] ; then
  echo "Home content after user password update:"
  find ~ -ls
fi

echo "Verifying if sudo can be run"
# If can sudo
if echo "$PASS" | sudo -S -v ; then
  echo 'Updating work folder permissions'
  echo "$PASS" | sudo -S chown "$USER:$USER" "${WORK_FLD}"
  [ -d "${WORK_FLD}/.kube" ] && echo "$PASS" | sudo -S chown "$USER:$USER" "${WORK_FLD}/.kube"
  adjust_docker_gid
else
  echo WARNING: cannot run as privileged user
fi

if [ "$DBG" != 'false' ] ; then
  echo "Home content after permission update"
  find ~ -ls
fi


# Check we can write into /work
touch "$WORK_FLD/.canary"
[ "$?" -ne 0 ] && echo WARNING: Unable to write on the volume mounted on $WORK_FLD. Manually fix your configurations to ensure the persistence of your artifacts.
rm -f "$WORK_FLD/.canary"

mkdir -p "${WORK_FLD}/.kube"
if [ ! -L "${HOME}/.kube" ] ; then
  echo "${HOME}/.kube folder does not exist, linking it to ${WORK_FLD}/.kube "
  ln -s "${WORK_FLD}/.kube" "${HOME}/.kube"
fi

if [ "$DBG" != 'false' ] ; then
  echo "Workdir content"
  find "$WORK_FLD" -ls
fi

echo "Container started" 1>&2
echo "$PASS" > "${HOME}/password"
if [ "$ALLOW_PASSWORD" != 'false' ] ; then
  echo "You can ssh into this container with user 'akamas' using the password '${PASS}' or the public key" 1>&2
else
  echo "You can ssh into this container with user 'akamas' using the public key" 1>&2
fi

case $DEBUG_LEVEL in
  1)
    DEBUG_LEVEL='-d'
    ;;
  2)
    DEBUG_LEVEL='-dd'
    ;;
  3)
    DEBUG_LEVEL='-ddd'
    ;;
  *)
    DEBUG_LEVEL=''
    ;;
esac


# Start sshd
if [ -n "${KUBERNETES_SERVICE_HOST}" ]; then
  # Set k8s startup probe
  echo started > /tmp/healthcheck
  /usr/sbin/sshd ${DEBUG_LEVEL:+"$DEBUG_LEVEL"} -p 2222 -D \
    -h "${HOME}/.sshd/ssh_host_rsa_key" \
    -h "${HOME}/.sshd/ssh_host_dsa_key" \
    -o "PidFile ${HOME}/.sshd/sshd.pid" \
    -o "UsePAM ${USE_PAM}" \
    -o "PasswordAuthentication $( [ "$ALLOW_PASSWORD" != 'false' ] && echo 'yes' || echo 'no' )" \
    -e |& tee -a "${HOME}/sshd.log"
else
  echo "$PASS" | sudo -S /usr/sbin/sshd ${DEBUG_LEVEL:+"$DEBUG_LEVEL"} -D \
    -h "${HOME}/.sshd/ssh_host_rsa_key" \
    -h "${HOME}/.sshd/ssh_host_dsa_key" \
    -o "UsePAM ${USE_PAM}" \
    -o "PasswordAuthentication $( [ "$ALLOW_PASSWORD" != 'false' ] && echo 'yes' || echo 'no' )" \
    -e |& tee -a "${HOME}/sshd.log"
fi
echo "SSHD exited"
sleep 5
