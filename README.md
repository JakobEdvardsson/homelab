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

## GitHub Actions Deploy

This repo includes a generic changed-stack deployment workflow:

- [deploy-changed-stacks.yml](/home/jakobe/code/homelab/.github/workflows/deploy-changed-stacks.yml)
- [deploy-changed-stacks.sh](/home/jakobe/code/homelab/scripts/deploy-changed-stacks.sh)
- [deploy-all-enabled-stacks.yml](/home/jakobe/code/homelab/.github/workflows/deploy-all-enabled-stacks.yml)
- [deploy-all-enabled-stacks.sh](/home/jakobe/code/homelab/scripts/deploy-all-enabled-stacks.sh)

It connects the GitHub runner to your tailnet with Tailscale, SSHes to the homelab host, pulls this repo on the server, diffs the pushed commit range, and reconciles only the changed Compose stacks.

Deployment rule:

- a changed stack is deployed only if its `autostart` file contains `true`, or if that stack is already running on the host
- before pulling, the script marks the checkout as a trusted Git directory with `git config --global --add safe.directory <repo>`
- the deploy aborts if the server checkout has uncommitted changes or local commits that are not on `origin/main`
- if `folderview/docker.json` changes, the deploy also copies it to `/boot/config/plugins/folder.view3/docker.json`

The repo also includes a full reconcile workflow:

- `Deploy All Enabled Stacks`

It pulls the homelab repo on the server and iterates every Compose stack under `docker/`. A stack is reconciled if any of these are true:

- `autostart` file contains `true`
- `enabled` file contains `true`
- the stack is already running on the host

For each eligible stack it runs:

- `docker compose --profile '*' pull`
- `docker compose up -d`

Required GitHub repository secrets:

- `TS_OAUTH_CLIENT_ID`
- `TS_OAUTH_SECRET`
- `HOMELAB_TAILSCALE_HOST`
- `HOMELAB_SSH_USER`
- `HOMELAB_SSH_PRIVATE_KEY`
- `HOMELAB_REPO_DIR`

Typical `HOMELAB_REPO_DIR`:

- `/mnt/user/appdata/homelab`
