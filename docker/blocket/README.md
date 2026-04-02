# Blocket

This stack pulls prebuilt images from `ghcr.io/jakobedvardsson/*`.

It mirrors the Booli stack shape:

- local Neo4j
- Blocket API
- Blocket web UI
- scheduled scraper
- Pushgateway for scraper metrics

Normal startup:

```bash
cd docker
make blocket.up
```

Neo4j Browser:

```text
http://<host>:${BLOCKET_NEO4J_HTTP_PUBLISHED_PORT}
```

Bolt:

```text
bolt://<host>:${BLOCKET_NEO4J_BOLT_PUBLISHED_PORT}
```

The shared data directory is mounted at:

- `${APPDATA_ROOT}/blocket/data`

Neo4j data lives under:

- `${APPDATA_ROOT}/blocket/neo4j/data`
- `${APPDATA_ROOT}/blocket/neo4j/logs`
- `${APPDATA_ROOT}/blocket/neo4j/import`
- `${APPDATA_ROOT}/blocket/neo4j/plugins`

Pushgateway state lives under:

- `${APPDATA_ROOT}/blocket/pushgateway`

Set the scraper search URL through `BLOCKET_SCRAPE_SEARCH_URL` in the shared env/secrets. Recommended value:

```text
https://www.blocket.se/mobility/search/car?body_type=6&body_type=1&body_type=2&body_type=4&body_type=8&body_type=3&body_type=9&mileage_to=20000&price_to=700000&year_from=2020
```
