.DEFAULT_GOAL := help
SHELL := /bin/bash

# Build environment variables used in the docker image building process
BUILD_USER_ID=$(shell id -u $(whoami))
BUILD_USER=${USER}
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

.PHONY: ci
ci:	check-target 			## Run target inside Docker. E.g.: make ci target=verify
	docker run --pull always --rm \
	-v $(repo_location):/workdir -w /workdir \
	-v $(AKAMAS_SSH_KEY):$(AKAMAS_SSH_KEY):ro \
	-v /var/run/docker.sock:/var/run/docker.sock \
	-v $(AKAMAS_LICENSE):$(AKAMAS_LICENSE) \
	--network host \
	--env CI_COMMIT_REF_NAME=$(CI_COMMIT_REF_NAME) \
	--env ENV_NAME=$(ENV_NAME) \
	--env ENV_DOMAIN=$(ENV_DOMAIN) \
	--env ENV=$(ENV) \
	--env AWS_ACCESS_KEY_ID=$(AWS_ACCESS_KEY_ID) \
	--env AWS_SECRET_ACCESS_KEY=$(AWS_SECRET_ACCESS_KEY) \
	--env AWS_DEFAULT_REGION=$(AWS_DEFAULT_REGION) \
	--env CI_JOB_TOKEN=${CI_JOB_TOKEN} \
	--env AKAMAS_SSH_KEY=$(AKAMAS_SSH_KEY) \
	--env CI_PIPELINE_ID=$(CI_PIPELINE_ID) \
	--env BUILD_USER_ID=$(BUILD_USER_ID) \
	--env BUILD_USER_ID=$(BUILD_USER_ID) \
	--env DOCKER_GROUP_ID=$(DOCKER_GROUP_ID) \
	registry.gitlab.com/akamas/devops/build-base/build-base:1.7.0 "make $(target)"

.PHONY: push
push:   login-ecr		## Push docker image
	docker push $(IMAGE_NAME):$(VERSION)

.PHONY: build
build: 			## Build docker image
	@echo "Building docker image" && \
	@docker build --pull -t ${IMAGE_NAME}:${VERSION} --build-arg BUILD_USER_ID=$(BUILD_USER_ID) --build-arg BUILD_USER=$(BUILD_USER) --build-arg DOCKER_GROUP_ID=$(DOCKER_GROUP_ID) .

.PHONY: info
info:    					## Print some info on the repo
	@echo "this_version: $(version)" && \
	echo "this_branch: $(branch)" && \
	echo "repo_location: $(repo_location)" &&\
