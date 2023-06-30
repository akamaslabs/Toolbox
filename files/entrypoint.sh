#!/bin/bash

echo "Container started" 1>&2
echo started > /tmp/healthcheck
if [ -e /tmp/akamas_password ]; then
	akamas_password=$(cat /tmp/akamas_password)
	echo "Password for user akamas is: $akamas_password" 1>&2
	rm -f /tmp/akamas_password
fi

echo $akamas_password | sudo -S /usr/sbin/sshd -D -E /var/log/sshd.log
