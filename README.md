# Kubernetes Cluster Demo
This is a collection of K3s demos by Kendell Crocker. The goal is to create short, reproducible demos that teach and demonstrate core Kubernetes skills.
Since this is an ongoing lab project of mine, I will continue to add demo labs to this repo over time.

## Initial Setup
A one-time base configuration for each node in the cluster.

Includes:
- Basic setup for nodes (Workers and Control Plane) 
- Connection Validation Steps
- Any other quirks and oddities I ran into

>[**Click here to go to the Initial Setup Guide**](./00-initial-setup/initial-setup.md)


## Demos

After completing the Initial Setup, pick any of the following demos.

*Note - Each demo is designed to be run independently; You do not have to complete all of them, or any of them in a specific order.*

- [**Demo 1 - The Basics**](./01-demo-basics/01-demo-basics.md): Kubernetes fundamentals. Set up a Pod, a Deployment and a Service using the official Nginx image.
- [**Demo 2 - Scheduling**](./02-demo-scheduling/02-demo-scheduling.md): Labels, taints, and tolerations. Learn how Kubernetes decides which node runs a workload.
- [**Demo 3 - Ingress with Traefik**](./03-demo-ingress/03-demo-ingress.md): Deomostrates accessing apps via Ingress and setup of Ingress Controllers.