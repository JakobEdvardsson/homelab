# Docker Setup for Unraid

This directory contains the Unraid-targeted replacement for the NixOS homelab config in [`~/code/nix-config`](/home/jakobe/code/nix-config).

Each stack directory is Compose Manager-friendly:

- `docker-compose.yml` is the project file name
- `name` contains the stack name for the Unraid UI

## Stacks

- `caddy`: reverse proxy and wildcard TLS
- `homepage`: dashboard with service and external links
- `booli`: Booli scraper, API, web UI, and worker services
- `gluetun`: VPN sidecar network namespace
- `qbittorrent`: torrent client routed through Gluetun
- `immich`: Immich app, ML, Redis, and Postgres
- `monitoring`: Prometheus, Grafana, Healthchecks, and exporters
- `dockge`: optional compose UI managing the same stack directories

## Initial setup

1. Copy [`docker/.env.example`](/home/jakobe/code/homelab/docker/.env.example) to `docker/.env`.
2. Adjust the Unraid paths, domain, Cloudflare token, and VPN settings.
3. If Docker's embedded DNS cannot resolve external names on Unraid, keep the explicit `DOCKER_DNS_*` values in `docker/.env`.
4. Create the shared Docker network:

```bash
docker network create caddy_internal
```

5. Create symlinks for `.env` files:

```bash
cd docker
make env
```

6. Start the base services first:

```bash
make caddy.up
make homepage.up
```

7. Start the application stacks:

```bash
make booli.up
make gluetun.up
make qbittorrent.up
make immich.up
make monitoring.up
```

8. Optional: start Dockge if you want a compose-focused UI in addition to Unraid:

```bash
make dockge.up
```

## Unraid path model

By default the stacks assume:

- app configs live under `${APPDATA_ROOT}`
- bulk media lives under `${MEDIA_ROOT}`
- downloads live under `${DOWNLOADS_ROOT}`
- Immich originals live under `${IMMICH_LIBRARY_ROOT}`

The example env file is already written for standard Unraid-style `/mnt/user/...` paths.

## Notes

- qBittorrent uses the `gluetun` container network namespace via `network_mode: container:gluetun`.
- Gluetun needs the qBittorrent WebUI and torrenting ports in `FIREWALL_INPUT_PORTS`.
- The Caddy stack assumes you want wildcard certs through Cloudflare DNS.
- The homepage stack includes external links for Unraid, UniFi, and the two Backrest endpoints from the old setup.
- Healthchecks still needs an explicit superuser bootstrap step:

```bash
cd docker/monitoring
docker compose run healthchecks /opt/healthchecks/manage.py createsuperuser --email admin@edvardsson.dev --password 'replace-me'
```

- Immich's upstream compose currently includes a `healthcheck.start_interval` on Postgres, but the Immich Unraid docs call out that Unraid's Docker Engine 24.x does not support that field. This repo leaves it out on purpose.
- Dockge points at the same `docker/` folder as the stack root, so do not manage the same stack from both Dockge and Compose Manager at the same time.
- Grafana dashboards are provisioned automatically from [`monitoring/grafana`](/home/jakobe/code/homelab/docker/monitoring/grafana), including the Booli dashboard.
- Grafana alerting is also provisioned from the same directory. Set `GRAFANA_DISCORD_WEBHOOK` in `docker/.env`, then recreate Grafana after alerting changes.
- The full deploy workflow reconciles any stack with `autostart=true`, `enabled=true`, or an already-running Compose project. It also pulls profiled services with `docker compose --profile '*' pull` before `up -d`.
