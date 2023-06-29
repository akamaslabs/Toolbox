#!/bin/bash

dest=management-container
if [ $# -gt 1 ]; then
	dest=$2
fi

sshpass -p "$1" ssh -o StrictHostKeyChecking=no akamas@$2