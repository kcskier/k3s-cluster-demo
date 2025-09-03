#!/usr/bin/env bash
set -euo pipefail
kubectl apply -f manifests/demo/nginx.yaml
kubectl -n demo get all