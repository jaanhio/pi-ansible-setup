# Setting up raspberry pi k8s cluster using Ansible

There's 5 parts to the setup:
1. SD card setup
2. Prepare Ansible inventory file
3. SSH setup
4. Networking setup
5. Docker & cgroups limit setup
5. K8s setup

Misc notes can be found in `./misc/notes` folder.

---
## SD Card setup
A script (`./scripts/pi-sdcard-setup.sh`) has been written to automate the preparation process, which consists of formatting SD card, copying the downloaded copy of Raspberry OS, setting up SSH.

1. Get SD card disk partition 
```
diskutil list
```
2. Execute script. Script expects disk partition as argument. 
```
./scripts/pi-sd-card-setup.sh /dev/disk2 <path-to-os-image>
```
3. You will be prompted for confirmation on whether the partition selected is indeed the correct one.

---
## Prepare Ansible inventory file
1. Get IP address of pis. This can be done 2 ways, either using `nmap` or using `arp`
```
sudo nmap -T4 <network-address>/<cidr>
sudo nmap -T4 192.168.1.0/24
```
You should see the raspberry pis details (MAC address, ip address) if they on the same network.

Alternatively,
```
arp -na | grep <raspberry-pi-mac-vendor-prefix>
```
List of raspberry pi mac vendor prefix can be found [here](https://udger.com/resources/mac-address-vendor-detail?name=raspberry_pi_foundation).

---
## SSH setup
For security reasons, various configs have been disabled for `sshd`. For more details, refer to `./ssh/file/sshd_config`.

1. Copy public key over to various pis. This step might be able to work with Ansible's [authorized_key module](https://docs.ansible.com/ansible/latest/collections/ansible/posix/authorized_key_module.html) but it requires some other dependencies on mac (sshpass, update xcode etc) and i do not want to break my dev setup at the moment so...some other time
```
ssh-copy-id -i <path-to-private-key> pi@<ip-address>
```
2. Run playbook that copies the `sshd` configs

```
ansible-playbook -i <path-to-inventory-file> <path-to-playbook>
ansible-playbook -i ./inventory ./ssh/playbook.yaml
```

---
## Networking setup

Taken from [here](https://github.com/geerlingguy/raspberry-pi-dramble/tree/master/setup/networking)
> When you plug a fresh new Raspberry Pi into your network, the default configuration tells the Pi to use DHCP to dynamically request an IP address from your network's router. Typically this is a pretty random address, and it can make configuration annoying.
To keep things simpler, I elected to jot down the MAC addresses of each of the Pis' onboard LAN ports (this stays the same over time), and map those to a set of contiguous static IP addresses so I can deploy, for example, the balancer to 10.0.1.60, the webservers to 10.0.1.61-62, and so on.

MAC address has already been obtained from the `Prepare Ansible inventory file`.

1. Using the MAC address, set up the `mac_address_mapping` in `./networking/vars.yaml`.

2. Also make sure various other values in template files are correct.
3. Run playbook that sets up network

```
ansible-playbook -i ./inventory ./networking/playbook.yaml
```
The pis should switch over to the new IP addresses quickly but it didn't work for me so i ran the following command
```
ansible -i ./inventory original -m shell -a "sleep 1s; shutdown -r now" -b -B 60 -P 0
```
On boot up, the pis should be changed to the newly assigned static IP addresses.

## k8s setup
Refer to https://github.com/jaanhio/k8s-playbook.
