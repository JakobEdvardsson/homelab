# Change Default Network Interface

Adding or changing PCIe devices (like an M.2 SSD or NIC) can shift PCIe addressing and rename network interfaces, breaking connectivity.
This will fix this by creating a link binding the mac address.


```bash
# Become root
sudo su

# Find the PCI device
lspci | grep -i eth
02:00.0 Ethernet controller: Intel Corporation Ethernet Controller I226-V (rev 04)

# Find the corresponding interface name
ls -l /sys/class/net/
lrwxrwxrwx 1 root root    0 May 16 15:25 enp2s0 -> ../../devices/pci0000:00/0000:00:1c.0/0000:02:00.0/net/enp2s0

# Get the MAC address
cat /sys/class/net/enp2s0/address
00:22:xx:xx:xx:xx

00:22:6b:51:2d:47
vim /etc/systemd/network/proxmox0.link


[Match]
MACAddress=00:22:xx:xx:xx:xx

[Link]
Name=proxmox0

vim /etc/network/interfaces

#replace 
bridge-ports eno1
#with
bridge-ports proxmox0

reboot
```
