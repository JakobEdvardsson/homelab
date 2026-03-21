# Booli

This stack pulls prebuilt images from `ghcr.io/jakobedvardsson/*`.

It also runs a local Neo4j instance inside the same stack.

Normal startup:

```bash
cd docker
make booli.up
```

One-time sold-history import:

```bash
cd docker/booli
docker compose --profile manual run --rm booli-sold-history
```

Neo4j Browser:

```text
http://<host>:${BOOLI_NEO4J_HTTP_PUBLISHED_PORT}
```

Bolt:

```text
bolt://<host>:${BOOLI_NEO4J_BOLT_PUBLISHED_PORT}
```

The shared data directory is mounted at:

- `${APPDATA_ROOT}/booli/data`

Neo4j data lives under:

- `${APPDATA_ROOT}/booli/neo4j/data`
- `${APPDATA_ROOT}/booli/neo4j/logs`
- `${APPDATA_ROOT}/booli/neo4j/import`
- `${APPDATA_ROOT}/booli/neo4j/plugins`

This stores:

- downloaded listing images
- any other local booli runtime data

Grafana dashboard and alert provisioning are automatic through the monitoring stack.

Booli alerts are Grafana-managed and routed through the `GRAFANA_DISCORD_WEBHOOK` value in `docker/.env`. After changing alert provisioning or the webhook, recreate Grafana:

```bash
cd docker/monitoring
docker compose up -d --force-recreate grafana
```

The source dashboard JSON also lives at:

- `docker/booli/grafana/booli-overview.json`
