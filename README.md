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

---
## Docker & cgroups limit setup
Encountered an issue where `kubeadm init` timed out, which prevented cluster from being created.

Logs from `kubeadm init` set to high verbosity `-v 10`.
```
[wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
I0311 15:10:40.823983   29341 round_trippers.go:425] curl -k -v -XGET  -H "Accept: application/json, */*" -H "User-Agent: kubeadm/v1.20.4 (linux/arm) kubernetes/e87da0b" 'https://192.168.1.221:6443/healthz?timeout=10s'
I0311 15:10:40.824625   29341 round_trippers.go:445] GET https://192.168.1.221:6443/healthz?timeout=10s  in 0 milliseconds
I0311 15:10:40.824699   29341 round_trippers.go:451] Response Headers:
```
Further checking on `kubelet` logs and status showed that `kubelet` is trying to ensure static pods are running before proceeding to next step in `kubeadm init`. This matches what is mentioned in the [init workflow](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#init-workflow).
>Generates static Pod manifests for the API server, controller-manager and scheduler. In case an external etcd is not provided, an additional static Pod manifest is generated for etcd.
Static Pod manifests are written to /etc/kubernetes/manifests; the kubelet watches this directory for Pods to create on startup.
Once control plane Pods are up and running, the kubeadm init sequence can continue.

`journalctl -xeu kubelet`
```
Mar 06 07:04:49 kube1 kubelet[2772694]: I0306 07:04:49.941976 2772694 clientconn.go:948] ClientConn switching balancer to "pick_first"
Mar 06 07:04:49 kube1 kubelet[2772694]: I0306 07:04:49.981461 2772694 kubelet.go:449] kubelet nodes not sync
Mar 06 07:04:49 kube1 kubelet[2772694]: I0306 07:04:49.981537 2772694 kubelet.go:449] kubelet nodes not sync
Mar 06 07:04:49 kube1 kubelet[2772694]: I0306 07:04:49.982577 2772694 kubelet_network_linux.go:56] Initialized IPv4 iptables rules.
Mar 06 07:04:49 kube1 kubelet[2772694]: I0306 07:04:49.982767 2772694 status_manager.go:158] Starting to sync pod status with apiserver
Mar 06 07:04:49 kube1 kubelet[2772694]: I0306 07:04:49.982832 2772694 kubelet.go:1829] Starting kubelet main sync loop.
Mar 06 07:04:49 kube1 kubelet[2772694]: E0306 07:04:49.983023 2772694 kubelet.go:1853] skipping pod synchronization - [container runtime status check may not have completed yet, PLEG is not healthy: pleg has yet to be successful]
Mar 06 07:04:49 kube1 kubelet[2772694]: E0306 07:04:49.984496 2772694 reflector.go:138] k8s.io/client-go/informers/factory.go:134: Failed to watch *v1.RuntimeClass: failed to list *v1.RuntimeClass: Get "https://192.168.1.221:6443/apis/node.k8s.io/v1/runtimeclasses?limit=500&resourceVersion=0": dial tcp 192.168.1.221:6>
Mar 06 07:04:50 kube1 kubelet[2772694]: E0306 07:04:50.083263 2772694 kubelet.go:1853] skipping pod synchronization - container runtime status check may not have completed yet
Mar 06 07:04:50 kube1 kubelet[2772694]: E0306 07:04:50.094657 2772694 controller.go:144] failed to ensure lease exists, will retry in 400ms, error: Get "https://192.168.1.221:6443/apis/coordination.k8s.io/v1/namespaces/kube-node-lease/leases/kube1?timeout=10s": dial tcp 192.168.1.221:6443: connect: connection refused
```

After some researching, chanced upon this [article](https://opensource.com/article/20/6/kubernetes-raspberry-pi) and the part mentioning about the output of `docker info` revealed that the issue was due to **incorrect docker cgroup driver** and **lack of cgroups limit support**.

This playbook will enable **cgroups limit** for pis running on Ubuntu.

## k8s setup
Refer to https://github.com/jaanhio/k8s-playbook.
