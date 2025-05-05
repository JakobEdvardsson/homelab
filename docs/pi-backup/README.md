# Pi Backup

### Things done:

- [Unattended Upgrades](../common/unattended-upgrades.md#unattended-upgrades)
- [Disable Root SSH](../common/disable-root-ssh.md#disable-root-ssh)
- [Unraid Pi Backup](./unraid-backup.md#unraid-pi-backup)

---

### Require a Password For Sudo

Default pi user is in the sudo group, That group is configured with passwordless sudo

1. You can confirm this with:

```bash
sudo cat /etc/sudoers.d/010_pi-nopasswd
#You’ll probably see: jakobe ALL=(ALL) NOPASSWD: ALL
```

2. Disable no password

```bash
sudo su
echo "jakobe ALL=(ALL) ALL" > /etc/sudoers.d/010_pi-nopasswd
```

2. Test the config

```bash
^D
sudo -k
sudo ls
```
