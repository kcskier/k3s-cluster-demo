# Initial Setup

One-time preparation to make your nodes ready for any demo in this repo.

> **Author’s notes:**  
>- You do not have to use Raspberry Pis to follow this lab. I’m using Pi 5s (plus a 3B+) because I had them on hand. I’ve documented the hoops I jumped through, but any Linux nodes that support K3s will work.  
>- I’ve kept the K3s setup as hardware-neutral as possible; any pi-specific bits are here mainly for reference.  
>- I used Ubuntu Server 25.04, so commands use Debian/Ubuntu syntax. Any Linux distro that supports K3s will work, so adjust commands as needed.


## Requirements

- 64-bit Ubuntu Server 25.04+
- SSH or terminal access on each node
- I recommend using a single LAN/subnet for all nodes

## My Hardware and Roles

My lab setup will include three nodes:

- `rd-rp51` — Raspberry Pi 5 → primary server (control plane)

- `rd-rp52` — Raspberry Pi 5 → secondary server (backup control plane)

- `rd-rp31` — Raspberry Pi 3B+ → worker/agent

## Raspberry Pi Specific Setup

### On Each Node:

#### 1. Update! (Standard first step to any installation on Linux)
```bash
sudo apt update -y
```

#### 2. Regardless of Linux Distribution, Kubernetes on `aarch64` requires that the cgroups flags be set:
```bash
sudo sed -i '1 s/$/ cgroup_memory=1 cgroup_enable=memory cgroup_enable=cpuset/' /boot/firmware/cmdline.txt
```

#### 3. Since we are on a Raspberry Pi and running on flash memory, we will disable the memory swap feature:
Disable memory swap:
```bash
sudo swapoff -a
```

Update fstab:
```bash
sudo sed -ri '/\sswap\s/s/^/#/' /etc/fstab
```

#### 4. Optional - Enable bridge netfilter. These are recommended settings for Kubernetes.
Enable br_netfilter at boot
```bash
sudo bash -c 'echo br_netfilter >/etc/modules-load.d/k8s.conf'
```

Enable persistent bridging that survives reboots
```bash
sudo bash -c 'cat >/etc/sysctl.d/99-k8s.conf <<EOF
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF'
```

#### 5. Reboot Node:
```bash
sudo reboot
```

#### 6. Verify that cgroup flags are present:
```bash
cat /proc/cmdline | tr ' ' '\n' | grep -E 'cgroup_memory=1|cgroup_enable=memory|cgroup_enable=cpuset'
```
Expected Results:
```text
cgroup_memory=1
cgroup_enable=memory
cgroup_enable=cpuset
```

#### 7. Verify that memory swap is disabled
```bash
swapon --show # Should return nothing
```
Expected Results:
```bash
free -h | awk '/Swap:/ {print}' # Should return a bunch of zeros
```

#### 8. Verify that bridge netfilter is enabled
Check that br_netfilter is enabled:
```bash
lsmod | grep br_netfilter
```

Verify that network bridge rules applied:
```bash
sysctl net.ipv4.ip_forward && \
sysctl net.bridge.bridge-nf-call-iptables && \
sysctl net.bridge.bridge-nf-call-ip6tables
```

Example Output:
```bash
# lsmod | grep br_netfilter
br_netfilter           32768  0
bridge                376832  1 br_netfilter

# sysctl commands. Each should be value of 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
```

## Installing K3s

### 1. Primary Control Node (`rd-rp51`)

#### 1. Install K3s server. (initialize the cluster) Replace `<NODE-NAME>` with the name of the primary node. (In my case, it's `rd-rp51`)
```bash
curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL=stable sh -s - server \
  --cluster-init \
  --node-name <NODE-NAME> \
  --tls-san <NODE-NAME> \
  --tls-san $(hostname -I | awk '{print $1}')
```

#### 2. (optional) world-readable kubeconfig for convenience
```bash
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
```
>*Don't do this in a production environment. This is for a lab, so it's ok here.*

#### 3. Verify that node is running
```bash
sudo kubectl get nodes
```

#### 4. Show the join token. You will need this to join the other nodes to the cluster.
```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

#### 5. Show the IP address of the Control Node. You will also need this for joining other nodes.
```bash
hostname -I | awk '{print $1}'
```

### 2. Secondary Control Node (`rd-rp52`)

>*It is worth mentioning that control planes require strict quorum. If this was a production environment, I would recommend setting up two agent nodes rather than two control plane nodes.*

#### 1. Replace `<TOKEN>` and `<ADDRESS>` with the value from Primary Node. Also `<NODE-NAME>` is the name of this node. (In my case, it's `rd-rp52`)
```bash
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_CHANNEL=stable \
  K3S_URL=https://<ADDRESS>:6443 \
  K3S_TOKEN=<TOKEN> \
  sh -s - server \
  --node-name <NODE-NAME>
```

#### 2. Verify that Node has connected to the cluster:
```bash
sudo kubectl get nodes
```
>*Node may take a few seconds to appear on the list*

### 3. Worker/Agent Node (`rd-rp31`)

#### 1. Replace `<TOKEN>` and `<ADDRESS>` with the value from Primary Node. Also `<NODE-NAME>` is the name of this node. (In my case, it's `rd-rp31`)
```bash
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_CHANNEL=stable \
  K3S_URL=https://<ADDRESS>:6443 \
  K3S_TOKEN=<TOKEN> \
  sh -s - agent \
  --node-name <NODE-NAME>
```

#### 2. Verify that Node has connected to cluster:
```bash
sudo kubectl get nodes
```
>*Node may take a few seconds to appear on the list*

## Conclusion

At this point, you should have a working K3s cluster operating on your nodes. You can verify by going to any node and running:
```bash
sudo kubectl get nodes
```

Example Output from my setup:
```text
NAME      STATUS   ROLES                       AGE   VERSION
rd-rp31   Ready    <none>                      2m   v1.33.4+k3s1
rd-rp51   Ready    control-plane,etcd,master   15m   v1.33.4+k3s1
rd-rp52   Ready    control-plane,etcd,master   13m   v1.33.4+k3s1
```

If you see all your nodes, congratulations! You have set up your cluster. You can now return to the demos and run one.

[**Click here to go to the Demos**](../README.md#demos)