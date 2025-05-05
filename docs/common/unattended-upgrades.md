# Unattended Upgrades

1. Update system

```bash
sudo apt update && sudo apt upgrade
```

2. Setup Unattended Upgrades

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades
sudo vim /etc/apt/apt.conf.d/50unattended-upgrades
```

Enable the following options

```bash
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-WithUsers "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
Unattended-Upgrade::SyslogEnable "true";
```

3. Run a dry-run

```bash
sudo unattended-upgrade --dry-run --debug
```
