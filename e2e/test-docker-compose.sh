#!/bin/bash

docker-compose pull
docker-compose up -d
sleep 10
docker ps
curr_password=$(docker exec toolbox cat /home/akamas/password)
container_id=$(docker ps | awk '/toolbox/ {print $1}')
docker cp test-remote-ssh.sh "${container_id}:/tmp/"
docker exec "$container_id" /tmp/test-remote-ssh.sh "$curr_password" 'toolbox'
res=$?
docker-compose down
if [ $res -eq 0 ]; then
	echo "Docker-compose Test PASSED"
else
	echo "Docker-compose Test FAILED"
	exit 1
fi

