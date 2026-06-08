#!/bin/sh
CONFIG="/config/qBittorrent/qBittorrent.conf"
[ -f "$CONFIG" ] || exit 0

# Plain CIDR list, comma-space separated — qBittorrent's QStringList INI format
WHITELIST="10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16"

# Replace existing entries; awk handles backslashes in keys safely
awk -v wl="$WHITELIST" '
    /^WebUI\\AuthSubnetWhitelistEnabled=/ { print "WebUI\\AuthSubnetWhitelistEnabled=true"; next }
    /^WebUI\\AuthSubnetWhitelist=/        { print "WebUI\\AuthSubnetWhitelist=" wl; next }
    { print }
' "$CONFIG" > "${CONFIG}.tmp"

# Insert after [Preferences] if not already present (grep -F: fixed-string, no regex)
if ! grep -qF 'WebUI\AuthSubnetWhitelistEnabled=' "${CONFIG}.tmp"; then
    awk '/^\[Preferences\]/ { print; print "WebUI\\AuthSubnetWhitelistEnabled=true"; next } 1' \
        "${CONFIG}.tmp" > "${CONFIG}.tmp2" && mv "${CONFIG}.tmp2" "${CONFIG}.tmp"
fi
if ! grep -qF 'WebUI\AuthSubnetWhitelist=' "${CONFIG}.tmp"; then
    awk -v wl="$WHITELIST" \
        '/^\[Preferences\]/ { print; print "WebUI\\AuthSubnetWhitelist=" wl; next } 1' \
        "${CONFIG}.tmp" > "${CONFIG}.tmp2" && mv "${CONFIG}.tmp2" "${CONFIG}.tmp"
fi

mv "${CONFIG}.tmp" "$CONFIG"
