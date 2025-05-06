# Docker Setup for Homelab

This repository contains Docker Compose configurations for various services.

## .env Symlink

Each service has a symlink to the global `.env` file in the `docker` directory.

To create the symlink for a service, run:

```bash
ln -s ../.env ./immich/.env
```

## Data
- All config files for each service should be stored in the **`/docker/<service-name>`**
- All appdata should be stored in the **`/data/<service-name>`** directory.
- Bulk data will be stored in Unraid with Docker Compose NFS.

## Backup Strategy

The `/data` folder contains all service data, backup this folder

<!-- #TODO: create a backup script / plan  -->

