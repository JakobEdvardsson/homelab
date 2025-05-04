# Ubuntu Container Host

## Post install steps

### Update System & Unattended Upgrades

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

---

### Disable root ssh login

1. Copy ssh key

```bash
# if password login is enabled
ssh-copy-id root@<ip>
# if password login disabled
# enter shell "Node > Shell"
vim .ssh/authorized_keys # append key
#or.
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC1aUDp1c38txQmImBCSU9N3zSRSNNWdeZvUBSx6QtLr jakobe@nixos" >> ~/.ssh/authorized_keys
# authorized_keys is a symlink to /etc/pve/priv/authorized_keys for the root user
```

2. Make copy of config `cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak`
3. `vim /etc/ssh/sshd_config`
4. Replace config with following

```bash
# Load additional config snippets if present
Include /etc/ssh/sshd_config.d/*.conf

# Use non-default port if needed (default is 22)
# Port 22

#PermitRootLogin prohibit-password  # Allow root only with SSH key
PermitRootLogin no             # Requires separate user
PasswordAuthentication no       # Disable password authentication
PermitEmptyPasswords no         # Disallow empty passwords
KbdInteractiveAuthentication no # Disable keyboard-interactive (e.g. MFA via PAM)
ChallengeResponseAuthentication no # Disable challenge-response auth
KerberosAuthentication no       # Disable Kerberos auth
GSSAPIAuthentication no         # Disable GSSAPI auth

MaxAuthTries 3                  # Limit failed login attempts
LoginGraceTime 0                # No grace period before login times out

UsePAM yes                      # Enable PAM for session management, sudo, etc.
X11Forwarding no                # Disable X11 GUI forwarding over SSH

PrintMotd yes                   # Show message of the day after login

AcceptEnv LANG LC_*             # Allow locale settings from client
Subsystem sftp /usr/lib/openssh/sftp-server  # Enable SFTP subsystem
```

5. Test config: `sshd -t`
6. Reload config: `systemctl reload sshd.service`
   Learn about ssh security [here](https://homelab.casaursus.net/proxmox-new-install-ssh/)

---
