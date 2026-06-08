#!/bin/bash
# Whitelist internal Docker subnets so Caddy's reverse proxy requests
# are never subject to qBittorrent's own auth / IP ban logic.
# Auth is handled upstream by authentik.

CONFIG="/config/qBittorrent/qBittorrent.conf"

if [ ! -f "$CONFIG" ]; then
    exit 0
fi

set_or_replace() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "$CONFIG"; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$CONFIG"
    else
        sed -i "/^\[Preferences\]/a ${key}=${value}" "$CONFIG"
    fi
}

set_or_replace 'WebUI\\AuthSubnetWhitelistEnabled' 'true'
set_or_replace 'WebUI\\AuthSubnetWhitelist' '10.0.0.0/8\t1,172.16.0.0/12\t1,192.168.0.0/16\t1'
