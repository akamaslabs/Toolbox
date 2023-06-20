.DEFAULT_GOAL := help
SHELL := /bin/bash

# Build environment variables used in the docker image building process
BUILD_USER=user #$(shell whoami)
BUILD_USER_ID=$(shell id -u $(whoami))
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
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":|: .*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

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
	--env BUILD_USER=$(BUILD_USER) \
	--env BUILD_USER_ID=$(BUILD_USER_ID) \
	--env DOCKER_GROUP_ID=$(DOCKER_GROUP_ID) \
	registry.gitlab.com/akamas/devops/build-base/build-base:1.8.1 /bin/sh -c "make $(target)"

.PHONY: push
push:   login-ecr		## Push docker image
	docker push $(IMAGE_NAME):$(VERSION)

.PHONY: build
build: 			## Build docker image
	@echo "Building docker image" && \
	env && \
	docker build --pull -t ${IMAGE_NAME}:${VERSION} --build-arg BUILD_USER_ID=$(BUILD_USER_ID) --build-arg BUILD_USER=$(BUILD_USER) --build-arg DOCKER_GROUP_ID=$(DOCKER_GROUP_ID) .

.PHONY: info
info:    					## Print some info on the repo
	@echo "this_version: $(version)" && \
	echo "this_branch: $(branch)" && \
	echo "repo_location: $(repo_location)" && \
	echo "BUILD_USER: $(BUILD_USER)" && \
	echo "BUILD_USER_ID: $(BUILD_USER_ID)" && \
	echo "DOCKER_GROUP_ID: $(DOCKER_GROUP_ID)"
