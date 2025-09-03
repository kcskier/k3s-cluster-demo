#!/usr/bin/env bash
set -euo pipefail


# Usage: sudo ./scripts/join_agent.sh <TOKEN> <K3S_URL>
TOKEN=${1:?"Usage: sudo ./scripts/join_agent.sh <TOKEN> <K3S_URL>"}
K3S_URL=${2:?"Usage: sudo ./scripts/join_agent.sh <TOKEN> <K3S_URL>"}


if [[ $EUID -ne 0 ]]; then echo "Run as root (sudo)."; exit 1; fi


# If the agent is already installed, just restart; otherwise install
if systemctl is-active --quiet k3s-agent; then
echo "k3s-agent is already installed. Rejoining with provided URL/TOKEN..."
# Update config for persistence
sudo mkdir -p /etc/rancher/k3s
cat <<YAML | sudo tee /etc/rancher/k3s/config.yaml >/dev/null
server: ${K3S_URL}
token: "${TOKEN}"
YAML
systemctl restart k3s-agent
else
echo "Installing k3s agent and joining ${K3S_URL}..."
curl -sfL https://get.k3s.io | K3S_URL="${K3S_URL}" K3S_TOKEN="${TOKEN}" sh -
fi


echo "✅ Agent joined: ${K3S_URL}"