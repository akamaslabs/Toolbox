#!/bin/bash

[ $# -gt 0 ] || exit 1

sshpass -p "$1" ssh -o StrictHostKeyChecking=no akamas@management-container
res=$(ps aux | grep ssh | grep -v sshd | grep -vc grep)
if [ "$res" -eq 2 ]; then
	echo "Test PASSED"
else
	echo "Test FAILED"
	exit 2
fi
