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
   - `folder.view`
7. For every stack directory, symlink the shared `.env` file into the stack directory:

```bash
cd /home/jakobe/code/homelab/docker/<stack>
ln -sf ../.env .env
```

8. If the stack should be managed through the helper targets, add it to [`docker/Makefile`](/home/jakobe/code/homelab/docker/Makefile).

Assume the shared env file is [`docker/.env`](/home/jakobe/code/homelab/docker/.env) unless there is a strong reason to isolate a stack's secrets.
