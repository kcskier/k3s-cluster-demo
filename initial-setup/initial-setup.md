# Initial-Setup

One-time preparation to make your nodes ready for any demo in this repo.

>### *Author's notes*:
>You do not have to use Raspberry Pis to follow this lab. I'm using this hardware because it's what I had available to me. I've documented the hoops I had to jump through, but any Linux node that supports K3s will work just fine.
To that end, I've tried to keep the K3s setup instructions as hardware-neutral as possible. The Pi-specific bits are only for those who need it.

>Also note that I've chosen to use Ubuntu 25.04 as my Linux distro. Therefore all my commands will be in the Debian/Ubuntu syntax. Again, any K3s supporting Linux distro will work, but you may need to modify the commands for your setup specifically.

## Requirements

- 64‑bit Ubuntu Server 25.04+ (Or your favorite Linux distro)
- SSH or Terminal access on each node
- Recommend use of a single LAN/Subnet for all nodes

## My Hardware and Roles

My lab setup will include three nodes:

- `rd-rp51` — Raspberry Pi 5 → primary server (control plane)

- `rd-rp52` — Raspberry Pi 5 → secondary server (backup control plane)

- `rd-rp31` — Raspberry Pi 3B+ → worker/agent

## Raspberry Pi Specific Setup

>*Note - All commands are in Debian/ubuntu syntax*

### On Each Node:

1. Update! (Standard first step to any installation on Linux)
```bash
sudo apt update -y
```

2. Regardless of Linux Distrobution, Kubernetes on `aarch64` requires that the cgroups flags be set:
```bash
sudo sed -i '1 s/$/ cgroup_memory=1 cgroup_enable=memory cgroup_enable=cpuset/' /boot/firmware/cmdline.txt
```

3. Reboot Node:
```bash
sudo reboot
```

4. Verify that flags are present:
```bash
cat /proc/cmdline | tr ' ' '\n' | grep -E 'cgroup_memory=1|cgroup_enable=memory|cgroup_enable=cpuset'

# Should return a list like this:
cgroup_memory=1
cgroup_enable=memory
cgroup_enable=cpuset
```

## Installing K3s

### Control Nodes:
#### 1. Primary Control Node (`rd-rp51`)

1. Install K3s server. (initialize the cluster) Replace `<NODE-NAME>` with the name of the primary node. (In my case, its `rd-rp51`)
```bash
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_CHANNEL=stable \
  sh -s - server \
  --cluster-init \
  --node-name <NODE-NAME> \
  --tls-san <NODE-NAME> \
  --tls-san $(hostname -I | awk '{print $1}')
```

2. (optional) world-readable kubeconfig for convenience
```bash
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
```
>*Don't do this in a production environment. This is for a lab, so it's ok here.*

3. Verify that node is running
```bash
sudo kubectl get nodes
```

4. Show the join token. You will need this to join the other nodes to the cluster.
```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

5. Show the IP address of the Control Node. You will also need this for joining other nodes.
```bash
hostname -I | awk '{print $1}'
```

#### 2. Secondary Control Node (`rd-rp52`)

1. Replace `<TOKEN>` and `<ADDRESS>` with the value from Primary Node. Also `<NODE-NAME>` is the name of this node. (In my case, its `rd-rp52`)
```bash
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_CHANNEL=stable \
  K3S_URL=https://<ADDRESS>:6443 \
  K3S_TOKEN=<TOKEN> \
  sh -s - server \
  --node-name <NODE-NAME>
```

2. Verify that Node has connected to cluster:
```bash
sudo kubectl get nodes
```
>*Node may take a few seconds to appear on the list*

#### 3. Worker/Agent Node (`rd-rp31`)

1. Replace `<TOKEN>` and `<ADDRESS>` with the value from Primary Node. Also `<NODE-NAME>` is the name of this node. (In my case, its `rd-rp31`)
```bash
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_CHANNEL=stable \
  K3S_URL=https://<ADDRESS>:6443 \
  K3S_TOKEN=<TOKEN> \
  sh -s - agent \
  --node-name <NODE-NAME>
```

2. Verify that Node has connected to cluster:
```bash
sudo kubectl get nodes
```
>*Node may take a few seconds to appear on the list*

## Conclusion

At this point, you should have a working K3s cluster operating on your nodes. You can verify by going to any node and running:
```bash
sudo kubectl get nodes

# Example Output from my setup:
NAME      STATUS   ROLES                       AGE    VERSION
rd-rp31   Ready    <none>                      5m   v1.33.4+k3s1
rd-rp51   Ready    control-plane,etcd,master   12m   v1.33.4+k3s1
rd-rp52   Ready    control-plane,etcd,master   15m   v1.33.4+k3s1
```

If you see all your nodes, congratulations! You have setup your cluster. You can now return to the demos and run one.

[**Click here to go to the Demos**](../README.md#demos)