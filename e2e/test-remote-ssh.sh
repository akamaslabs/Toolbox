#!/bin/bash

sshpass -p "$1" ssh -o StrictHostKeyChecking=no akamas@$2