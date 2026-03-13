# homelab

This repo is now structured to recreate the active setup from [`~/code/nix-config`](/home/jakobe/code/nix-config) on Unraid using Docker Compose stacks.

The migrated setup covers:

- Caddy with wildcard Cloudflare DNS ACME
- Homepage dashboard
- Jellyfin
- Jellyseerr
- Prowlarr
- Radarr
- Sonarr
- Bazarr
- Deluge behind a VPN sidecar
- Immich
- Prometheus
- Grafana
- Healthchecks

The main NixOS to Unraid substitutions are:

- `cockpit` is not recreated because Unraid already provides the host management UI
- `wireguard-netns` + `tailscale-exit-vpn` is replaced with a Docker VPN sidecar pattern for Deluge
- homepage external links now point at Unraid and the other appliances directly

Start with [`docker/README.md`](/home/jakobe/code/homelab/docker/README.md) and copy [`docker/.env.example`](/home/jakobe/code/homelab/docker/.env.example) to `docker/.env`.
