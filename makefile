.DEFAULT_GOAL := help
SHELL := /bin/bash

# Build environment variables used in the docker image building process
BUILD_USER_ID=$(shell id -u $(whoami))
BUILD_USER=${USER}
DOCKER_GROUP_ID ?= $(shell getent group | grep docker | cut -d: -f3)

branch := $(shell git rev-parse --abbrev-ref HEAD)
version := $(shell cat version)
repo_location := $(strip $(shell  git rev-parse --show-toplevel))

#docker registry user
DOCKER_REGISTRY_USER ?= gitlab-ci-token

current_tag=$(shell git tag --points-at HEAD)

VERSION ?= $(version)

.PHONY: help
help: 							## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":|: .*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: build
build: 			## Build container image
	@docker build --pull --build-arg BUILD_USER_ID=$(BUILD_USER_ID) --build-arg BUILD_USER=$(BUILD_USER) --build-arg DOCKER_GROUP_ID=$(DOCKER_GROUP_ID) .

.PHONY: push
push:						## Push to ECR
	@docker push

.PHONY: info
info:    					## Print some info on the repo
	@echo "this_version: $(version)" && \
	echo "this_branch: $(branch)" && \
	echo "repo_location: $(repo_location)" &&\
