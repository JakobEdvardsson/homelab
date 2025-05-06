# Docker Setup for Homelab

This repository contains Docker Compose configurations for various services.

## Setup

1. Clone the repo

```bash
git clone https://github.com/JakobEdvardsson/homelab.git
```

2. Install docker: [Guide](../docs/common/docker-install.md#docker-installation)
3. Install make

```bash
sudo apt install make
```

4. Ready to go!

## Makefile usage

To manage all containers

```bash
make pull up down
```

To manage a individual container

```bash
make <project-name>.<docker-compose-command>
# example make immich.up | make immich.down
```

## Adding a service

When adding a new service, make sure to add the project to the Makefile under `PROJECTS`

## .env Symlink

Each service has a symlink to the global `.env` file in the `docker` directory.

To create the symlink for a service, run:

```bash
make service-name.env
# or
ln -sf ../.env ./immich/.env

# for all services:
make env-projects
```

## Data

- All config files for each service should be stored in the **`/docker/<service-name>`**
- All appdata should be stored in the **`/data/<service-name>`** directory.
- Bulk data will be stored in Unraid with Docker Compose NFS.

## Backup Strategy

The `/data` folder contains all service data, backup this folder

<!-- #TODO: create a backup script / plan  -->
