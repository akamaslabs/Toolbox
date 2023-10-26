#!/bin/bash

if [ ! -d /work/.ssh/ ]; then
	# wait for /work volume mounted and chowned
	retries=12
	mkdir -p /work/.ssh/ 2>/dev/null
	while [ ! -d /work/.ssh/ ] ; do
		if [ $retries -eq 0 ] ; then
			echo Too many retries. Moving on
			break
		else
			echo Waiting for /work/ to be writable && sleep 5
			mkdir -p /work/.ssh/ 2>/dev/null
			retries=$((retries - 1))
		fi
	done

	ssh-keygen -q -f /work/.ssh/id_rsa -N '' -t rsa -b 2048
	cp /work/.ssh/id_rsa.pub /work/.ssh/authorized_keys
fi

if [ ! -e /work/akamas_password ]; then
	# generate a random password
	akamas_password=$(openssl rand -hex 8)
	echo $akamas_password > /work/akamas_password
else
	akamas_password=$(cat /work/akamas_password)
fi

echo "akamas:${akamas_password}" | sudo chpasswd
sed "s/#PASSWORD#/$akamas_password/" /home/akamas/README > /work/README
mkdir -p /work/.kube

if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
	echo $akamas_password | sudo -S ssh-keygen -q -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
fi
if [ ! -f /etc/ssh/ssh_host_dsa_key ]; then
	echo $akamas_password | sudo -S ssh-keygen -q -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa
fi

echo "Container started" 1>&2
echo started > /tmp/healthcheck
echo "You can ssh into this container with user 'akamas' and password '$akamas_password'" 1>&2

echo $akamas_password | sudo -S /usr/sbin/sshd -D -E /var/log/sshd.log
