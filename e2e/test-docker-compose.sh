#!/bin/bash

docker-compose pull
docker-compose up -d
sleep 10
docker ps
curr_password=$(docker compose logs management-container | grep -i 'You can ssh into this container' | grep -o "'[^']*'" | sed -n '2p' | tr -d "'\n")
container_id=$(docker ps | grep management-container | cut -d ' ' -f 1)
docker cp test-remote-ssh-docker.sh ${container_id}:/tmp/
docker exec $container_id /tmp/test-remote-ssh-docker.sh "$curr_password"
res=$?
docker-compose down
if [ $res -eq 0 ]; then
	echo "Docker-compose Test PASSED"
else
	echo "Docker-compose Test FAILED"
	exit 1
fi
