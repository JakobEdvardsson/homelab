# Homelab Agent Notes

When adding a new service to this repo:

1. Add the service stack or service definition under [`docker`](/home/jakobe/code/homelab/docker).
2. For every new user-facing service, add the reverse proxy route to [`docker/caddy/config/Caddyfile`](/home/jakobe/code/homelab/docker/caddy/config/Caddyfile) if the service should be reachable through Caddy.
3. For every new user-facing service, add the Homepage entry to [`docker/homepage/config/services.yaml`](/home/jakobe/code/homelab/docker/homepage/config/services.yaml).
4. For every service that is reverse proxied by Caddy, make sure the target container is reachable on the `caddy_internal` Docker network.
5. For every new stack directory, create a `name` file so Unraid Compose Manager / Dockge can identify the stack.
6. For every container, add the Unraid metadata labels in compose when they make sense:
   - `net.unraid.docker.managed`
   - `net.unraid.docker.icon`
   - `net.unraid.docker.webui`
   - `net.unraid.docker.shell`
   - `folder.view3`
   - If you add a new `folder.view3` label value, also add the matching folder definition to [`folderview/docker.json`](/home/jakobe/code/homelab/folderview/docker.json).
   - Whenever [`folderview/docker.json`](/home/jakobe/code/homelab/folderview/docker.json) changes, copy it to the live Unraid plugin path because `/boot` is FAT32 and cannot use symlinks:

```bash
cp /mnt/user/appdata/homelab/folderview/docker.json /boot/config/plugins/folder.view3/docker.json
```
7. For every stack directory, commit a stack-local symlink from `.env` to the shared env file so the repo already contains:

```bash
cd /home/jakobe/code/homelab/docker/<stack>
ln -sf ../.env .env
```

Do not leave this as a manual post-step. The `.env` symlink should exist in git for every stack unless there is a strong reason not to share the root env file.

8. If the stack should be managed through the helper targets, add it to [`docker/Makefile`](/home/jakobe/code/homelab/docker/Makefile).
9. For every new stack directory, add a matching boolean `workflow_dispatch` input and selection line to [`deploy-selected-stacks.yml`](/home/jakobe/code/homelab/.github/workflows/deploy-selected-stacks.yml) so the manual deploy UI stays in sync with the available stacks.
10. If a stack should start automatically, commit an `autostart` file with the contents `true`. Do not rely on an ignored local file for deploy behavior.

Assume the shared env file is [`docker/.env`](/home/jakobe/code/homelab/docker/.env) unless there is a strong reason to isolate a stack's secrets.
