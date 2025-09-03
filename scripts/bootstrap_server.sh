#!/usr/bin/env bash
set -euo pipefail


if [[ $EUID -ne 0 ]]; then echo "Run as root (sudo)."; exit 1; fi


# Install k3s server (control-plane)
curl -sfL https://get.k3s.io | sh -s - server --write-kubeconfig-mode=644


# Gather values for easy agent joins
TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)
IP=$(hostname -I | awk '{print $1}')
URL="https://${IP}:6443"


cat <<EOF


✅ k3s server installed.


To join agents, run this on each agent node:


sudo ./scripts/join_agent.sh '${TOKEN}' '${URL}'


(Or copy/paste the values yourself: TOKEN='${TOKEN}', URL='${URL}')
EOF