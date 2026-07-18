# Unify Web SaaS Deployment into Docker Compose and Helm Chart

This document outlines the steps and architecture to simplify the deployment of the Web SaaS domain by combining the disparate Ansible-driven deployments (PostgreSQL, Stunnel, Accounts, Billing, Console, Caddy) into consolidated artifacts, adding a Dockerfile for the billing service, and provisioning Packer templates for golden images.

## Proposed Changes

### 1. Docker Compose (Single Node)
A unified `docker-compose.yml` was created in `playbooks/roles/vhosts/docker-compose/web-saas`.

**Services:**
- `postgres`: PostgreSQL 17 database.
- `stunnel-server`: Wraps PostgreSQL port securely.
- `stunnel-client`: Connects to `stunnel-server` and exposes the port locally to other containers.
- `accounts`: Accounts service.
- `billing`: Billing service.
- `console`: Frontend console dashboard.
- `caddy`: Containerized reverse proxy serving `accounts`, `billing`, and `console`.

### 2. Billing Service Dockerfile
A `Dockerfile` for the `billing-service` was created to transition it from a systemd binary to a containerized application, utilizing a multi-stage Go build.

### 3. Helm Chart (Kubernetes)
A unified Helm Chart was created in `artifacts/oci/charts/web-saas` utilizing sub-charts.

- **Main Chart**: `web-saas`
- **Subcharts**: `postgresql`, `stunnel`, `accounts`, `billing`, `console`, `caddy`.

### 4. Packer Golden Images
Packer configurations were created in `artifacts/packer/` for three golden images based on Debian 13 and Ubuntu 26.04 supporting Docker and K3s/K8s node combinations.

## Verification Plan
### Automated Tests
The following commands should be executed to validate syntax:
- `docker compose config`
- `helm lint`
- `packer validate`
