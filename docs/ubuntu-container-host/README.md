# Ubuntu Container Host

## Post install steps

### Enable QEMU guest agent

1. Enable `Run guest-trim after a disk move or VM migration`
   \_Node > VM > Options > QEMU Guest Agent > toggle `Run guest-trim after a disk move or VM migration`
2. `sudo apt install qemu-guest-agent`

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
6. Reload config: `sudo systemctl reload ssh`
   Learn about ssh security [here](https://homelab.casaursus.net/proxmox-new-install-ssh/)

---

## Docker installation

[Docker install guide](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)

1. Set up Docker's apt repository.

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

2. Install the Docker packages.

```bash
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

```

3. Verify that the installation is successful by running the hello-world image:

```bash
 sudo docker run hello-world

```

4. Manage Docker as a non-root user

```bash
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

docker run hello-world # Verify
```

5. Configure Docker to start on boot with systemd

```bash
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

#To stop this behavior, use disable instead.
#sudo systemctl disable docker.service
#sudo systemctl disable containerd.service
```
