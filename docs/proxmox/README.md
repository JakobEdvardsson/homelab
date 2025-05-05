# Proxmox

### Links

- [Proxmox VE Helper-Scripts](https://community-scripts.github.io/ProxmoxVE/scripts)

---

### Things done:

- [Disable Root SSH](../common/disable-root-ssh.md#disable-root-ssh)

---

### Create new admin user

1. Add user and add to sudo group

```bash
adduser jakobe
apt install sudo
usermod -aG sudo jakobe
```

2. Setup key based ssh

```bash
su jakobe
mkdir ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC1aUDp1c38txQmImBCSU9N3zSRSNNWdeZvUBSx6QtLr jakobe@nixos" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

3. Import user into proxmox

```bash
pveum user add jakobe@pam
pveum user list # verify
echo 'export PATH="$PATH:/usr/sbin:/sbin"' >> ~/.profile #give user access to pveum etc.
```

4. Assign permissions to the user

```bash
pveum acl modify / --roles PVEAdmin --users jakobe@pam
```

5. Setup 2FA

---

### Disable Enterprise Repositories

1. Navigate to _Node > Repositories_ Disable the enterprise repositories.
2. Now click Add and enable the no subscription repository. Finally, go _Updates > Refresh_.
3. Upgrade your system by clicking _Upgrade_ above the repository setting page.

---

### Enable IOMMU

1. `vim /etc/default/grub`
2. Append `intel_iommu=on` or `amd_iommu=on` in `GRUB_CMDLINE_LINUX_DEFAULT="quiet"`

```
# Should look like this
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
```

3. Next run the following commands and reboot your system.

```bash
update-grub
reboot
```

4. Check to make sure everything is enabled.

```bash
dmesg | grep -e DMAR -e IOMMU
dmesg | grep 'remapping'
pvesh get /nodes/{nodename}/hardware/pci --pci-class-blacklist ""
```

5. Blacklist drivers for GPU Passthrough

```bash
# AMD GPUs
echo "blacklist amdgpu" >> /etc/modprobe.d/blacklist.conf
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
# NVIDIA GPUs
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia*" >> /etc/modprobe.d/blacklist.conf
# Intel GPUs
echo "blacklist i915" >> /etc/modprobe.d/blacklist.conf
```

## Learn about enabling PCI Passthrough [here](https://pve.proxmox.com/wiki/PCI_Passthrough)

### Delete local-lvm and Resize local (fresh install)

> **Caution**: This will delete all files in the lvm

1. Delete local-lvm manually from web interface under _Datacenter > Storage_.

```
lvremove /dev/pve/data
lvresize -l +100%FREE /dev/pve/root
resize2fs /dev/mapper/pve-root
```

3. Check to ensure your local storage partition is using all avalible space. Reassign storage for containers and VM if needed.
