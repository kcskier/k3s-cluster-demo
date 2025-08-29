# Kubernetes Cluster Demo

A lightweight multi-node Kubernetes lab running on **Raspberry Pi 5/3 (Alpine Linux)** with **k3s** and **Tailscale** networking.  
This project demonstrates core Kubernetes concepts on constrained ARM hardware and serves as a portfolio example.

---

## 🚀 Features

- Multi-node **k3s cluster** (control-plane + workers)
- Remote access via **Tailscale** (coyote node owns host network)
- Deployment of a sample **FastAPI** app with:
  - Readiness probes
  - Service + Ingress (Traefik)
  - Horizontal Pod Autoscaler (HPA)
- Python verification script (`verify/verify_lab.py`) checks cluster health and app reachability
- Organized repo structure for clarity (manifests, scripts, docs)

---

## 📂 Repo Layout

