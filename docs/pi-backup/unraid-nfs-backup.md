# Unraid Pi Backup

1. Enable NFS in Unraid
   _Settings > NFS > Enable NFS: yes_
2. Enable NFS of share
   _Shares > <share> > NFS Security Settings_

   - Export: true
   - Security: private
   - Rule: `10.0.0.31(ro,async,no_subtree_check,sec=sys,insecure,anongid=100,anonuid=99,no_root_squash)`

3. Setup NFS on Pi Backup

```bash
sudo apt install nfs-common
sudo mkdir -p /mnt/backup /mnt/nfs/immich /mnt/nfs/jakob

# To test the setup
sudo mount -t nfs -o ro 10.0.0.42:/mnt/user/immich/library /mnt/nfs/immich # test NFS
sudo mount /dev/disk/by-label/backup_drive /mnt/backup/ # test USB mount
```

4. Setup script

```bash
sudo su
mkdir /root/scripts
touch /root/scripts/backup.sh
vim /root/scripts/backup.sh
# Paste code from below:
# Update the DISCORD_WEBHOOK_URL
chmod 700 /root/scripts/backup.sh # Only root have access
```

5. Cron job

```bash
sudo crontab -e

# Daily at 3:00 AM
0 3 * * * /root/scripts/backup.sh

# For logs:
sudo mkdir -p /var/log/backup
sudo chmod 755 /var/log/backup

0 3 * * * /root/scripts/backup.sh > /var/log/backup/$(date +\%Y\%m\%d_\%H\%M\%S).log 2>&1

```

6. Run backup manually

```bash
sudo su
nohup /root/scripts/backup.sh > /var/log/backup/$(date +\%Y\%m\%d_\%H\%M\%S).log 2>&1 &
```

### Backup script

```bash
#!/bin/bash

# Define the Discord webhook URL
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/YOUR_WEBHOOK_URL"
NFS_SERVER="10.0.0.42"

# Function to send a message to Discord
send_discord_message() {
    local message="$1"
    curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"content\": \"$message\"}" \
    "$DISCORD_WEBHOOK_URL" > /dev/null
}

# Mount USB backup drive
if ! mountpoint -q /mnt/backup; then
    sudo mount /dev/disk/by-label/backup_drive /mnt/backup
    if [ $? -ne 0 ]; then
        echo "Error mounting USB drive to /mnt/backup"
        send_discord_message "❌ Error mounting USB drive to /mnt/backup"
        exit 1
    else
        echo "✅ USB drive mounted to /mnt/backup"
    fi
fi

# Mount NFS shares
echo "Mounting NFS shares..."
sudo mount -t nfs -o ro "$NFS_SERVER:/mnt/user/immich/library" /mnt/nfs/immich || {
    echo "❌ Error mounting Immich NFS share"
    send_discord_message "❌ Failed to mount Immich NFS share"
    exit 1
}
sudo mount -t nfs -o ro "$NFS_SERVER:/mnt/user/jakob" /mnt/nfs/jakob || {
    echo "❌ Error mounting Jakob NFS share"
    send_discord_message "❌ Failed to mount Jakob NFS share"
    exit 1
}

# Backups
echo "🔁 Starting backup for Jakob Immich..."
rsync -a -h --info=progress2 --stats --mkpath /mnt/nfs/immich/jakob /mnt/backup/immich/jakob || \
    send_discord_message "❌ Jakob Immich backup failed @ $(date +%H:%M:%S)"

echo "🔁 Starting backup for Melina Immich..."
rsync -a -h --info=progress2 --stats --mkpath /mnt/nfs/immich/melina /mnt/backup/immich/melina || \
    send_discord_message "❌ Melina Immich backup failed @ $(date +%H:%M:%S)"

echo "🔁 Starting backup for Jakob folder..."
rsync -a -h --info=progress2 --stats --exclude 'Appdata backup' --mkpath /mnt/nfs/jakob /mnt/backup/jakob || \
    send_discord_message "❌ Jakob backup failed @ $(date +%H:%M:%S)"
#
# Unmount everything
echo "🧹 Cleaning up..."

for MOUNT in /mnt/nfs/immich /mnt/nfs/jakob /mnt/backup; do
    if mountpoint -q "$MOUNT"; then
        sudo umount "$MOUNT" || {
            echo "❌ Failed to unmount $MOUNT"
            send_discord_message "⚠️ Failed to unmount $MOUNT"
        }
    fi
done

echo "✅ Backup and cleanup completed successfully."
send_discord_message "✅ Pi backup completed @ $(date +%H:%M:%S)"
```
