# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Toolbox is a Docker image providing a collection of essential DevOps tools (vim, jq, yq, kubectl, helm, k9s, aws-cli, docker-cli, akamas-cli, openssh, openjdk 17) that serves as an execution environment for Airflow tasks within the Akamas ecosystem.

## Build Commands

```bash
# Build the Docker image locally
make build

# Push image to AWS ECR
make push

# Run a make target inside the build-base container (used in CI)
make ci target=<target-name>

# Display repo info (version, branch)
make info
```

## Testing

```bash
# Run end-to-end tests using Docker Compose
make e2e-docker

# Run end-to-end tests on Kubernetes
make e2e-kube

# Generate docker-compose.yml from template (for e2e tests)
make build-docker-compose-yml
```

E2E tests validate SSH connectivity by starting the container, extracting the auto-generated password, and running SSH login tests.

## Linting

Pre-commit hooks handle linting. Install with `pre-commit install`, then:
- **Dockerfile**: hadolint (ignores DL3008, DL3013, DL4001)
- **Shell scripts**: shellcheck (excludes SC2181)
- **YAML/JSON**: Syntax validation

## Architecture

### Core Files
- `Dockerfile` - Main image definition (Ubuntu 22.04 base)
- `files/entrypoint.sh` - Container startup: SSH key generation, user setup, environment detection (Docker vs K8s)
- `makefile` - Build orchestration, ECR push, e2e test targets
- `version` - Current version number

### Docker Image Details
- **User**: `akamas` (UID 199), member of `docker` group (GID 200)
- **SSH**: Port 22 (Docker) or 2222 (Kubernetes)
- **Persistence**: `/work` volume for artifacts and scripts
- **Kubeconfig**: `/work/.kube/config`

### Deployment Submodule
`deploy/` is a git submodule containing Ansible playbooks and roles for AWS EC2, Kubernetes, and OpenShift deployments.

## CI/CD Pipeline

GitLab CI stages: `build-push-image` → `deploy` → `e2e` → `e2e-cleanup`

Skip controls via commit message:
- `ci_skip` or `skip_ci`: Skip entire pipeline
- `e2e_skip` or `skip_e2e`: Skip e2e tests
- `e2e`: Force e2e tests

## Key Environment Variables (Container)

| Variable | Purpose |
|----------|---------|
| `CUSTOM_PASSWORD` | Override auto-generated SSH password |
| `ALLOW_PASSWORD` | Enable/disable password auth |
| `DEBUG_LEVEL` | SSH debug verbosity (0-3) |

## Registry

AWS ECR: `485790562880.dkr.ecr.us-east-2.amazonaws.com/akamas/toolbox`
