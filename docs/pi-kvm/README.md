# Pi KVM

#### Updating PiKVM OS

```bash
pikvm-update
```

---

### Default passwords:

- Linux OS-level admin (SSH, console...):

  - Username: root
  - Password: root

- KVM user (Web Interface, API, VNC...):
  - Username: admin
  - Password: admin
  - No 2FA code

---

### Changing PiKVM Passwords

```bash
ssh root@ip

rw # Switch filesystem to RW-mode
passwd root
kvmd-htpasswd set admin
ro # Switch filesystem to RO-mode
systemctl restart kvmd kvmd-nginx
```
