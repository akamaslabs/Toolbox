#!/bin/bash

echo "Container started" 1>&2
echo started > /tmp/healthcheck
if [ ! -e /work/akamas_password ]; then
	akamas_password=$(openssl rand -hex 8)
	echo $akamas_password > /work/akamas_password
	echo "akamas:${akamas_password}" | sudo chpasswd
	sed -i "s/#PASSWORD#/$akamas_password/" /home/akamas/README
else
	akamas_password=$(cat /work/akamas_password)
fi
echo "Password for user akamas is: $akamas_password" 1>&2

echo $akamas_password | sudo -S /usr/sbin/sshd -D -E /var/log/sshd.log
