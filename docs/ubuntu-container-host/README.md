# Ubuntu Container Host

### Things done:

- [Unattended Upgrades](../common/unattended-upgrades.md#unattended-upgrades)
- [Disable Root SSH](../common/disable-root-ssh.md#disable-root-ssh)
- [Docker Installation](../common/docker-install.md#docker-installation)

---

### Enable QEMU guest agent

1. Enable `Run guest-trim after a disk move or VM migration` in Proxmox
   _Node > VM > Options > QEMU Guest Agent > toggle `Run guest-trim after a disk move or VM migration`_
2. Install guest agent

```bash
sudo apt install qemu-guest-agent
```

---
