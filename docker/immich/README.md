# Immich notes

This stack is the Unraid replacement for the old NixOS `services.immich` setup.

It intentionally omits the upstream Postgres `healthcheck.start_interval` field because Immich's Unraid docs note that Unraid systems on Docker Engine 24.x reject that key.

After first boot:

1. Create the admin account in the web UI.
2. Enable hardware transcoding if `/dev/dri` is available on the host.
3. Set the storage template you want for imported media.
4. Generate an API key if you want to script uploads.

The stack keeps the app, ML, Redis, and Postgres together and exposes Immich both directly and through Caddy.
