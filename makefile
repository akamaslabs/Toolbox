.DEFAULT_GOAL := help
SHELL := /bin/bash

# Build environment variables used in the docker image building process
DOCKER_GROUP_ID ?= $(shell getent group | grep docker | cut -d: -f3)

branch := $(shell git rev-parse --abbrev-ref HEAD)
version := $(shell cat version)
repo_location := $(strip $(shell  git rev-parse --show-toplevel))

DOCKER_REGISTRY_USER ?= gitlab-ci-token

current_tag=$(shell git tag --points-at HEAD)

VERSION ?= $(version)
AKAMAS_REGISTRY := 485790562880.dkr.ecr.us-east-2.amazonaws.com
IMAGE_NAME := ${AKAMAS_REGISTRY}/akamas/management-container

AWS_DEFAULT_REGION ?= us-east-2

.PHONY: help
help: 							## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":|: .*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: login-ecr
login-ecr: 									## Login to ECR Docker Registry
	echo "Logging in to AWS ECR" && \
	eval $(shell aws ecr get-login --no-include-email --region $(AWS_DEFAULT_REGION))

.PHONY: check-target
check-target:
ifeq ($(strip $(target)),)
	$(error target is undefined)
endif

.PHONY: ci
ci:	check-target 			## Run target inside Docker. E.g.: make ci target=build
	docker run --pull always --rm \
	-v $(repo_location):/workdir -w /workdir \
	-v /var/run/docker.sock:/var/run/docker.sock \
	--network host \
	--env AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
	--env AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
	--env AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) \
	--env DOCKER_GROUP_ID=$(DOCKER_GROUP_ID) \
	registry.gitlab.com/akamas/devops/build-base/build-base:1.8.1 /bin/sh -c "make $(target)"

.PHONY: push
push:   login-ecr		## Push docker image
	docker push $(IMAGE_NAME):$(VERSION)

.PHONY: build
build: 			## Build docker image
	@echo "Building docker image" && \
	env && \
	docker build --pull -t ${IMAGE_NAME}:${VERSION} --build-arg DOCKER_GROUP_ID=$(DOCKER_GROUP_ID) .

.PHONY: build-docker-compose-yml
build-docker-compose-yml:    					## Build e2e/docker-compose.yml
	@export CURR_VERSION=${VERSION} && cat e2e/docker-compose.yml.template | envsubst >e2e/docker-compose.yml

.PHONY: e2e-test-docker
e2e-test-docker: build-docker-compose-yml					## Test e2e with docker-compose
	cd e2e && \
	docker-compose up -d && \
	sleep 10 && \
	curr_password=$(shell docker-compose logs management-container | grep Password | cut -d ':' -f 2 | sed 's/ //') && \
	echo $(curr_password) && \
	docker-compose down && \
	cd -

.PHONY: info
info:    					## Print some info on the repo
	@echo "this_version: $(version)" && \
	echo "this_branch: $(branch)" && \
	echo "repo_location: $(repo_location)" && \
	echo "DOCKER_GROUP_ID: $(DOCKER_GROUP_ID)"