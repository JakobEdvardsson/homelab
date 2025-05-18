## Setup
```bash
docker exec -it crowdsec bash
cscli capi register
cscli console enroll -e context xxxxxxxxxxxxxxxxxxxxxxxxxx
# Accept enroll at https://app.crowdsec.net

# Caddy bouncer
docker exec crowdsec cscli bouncers add caddy-bouncer
```
