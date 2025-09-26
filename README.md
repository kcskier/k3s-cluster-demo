# Kubernetes Cluster Demos
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

*Note - Each demo is designed to be run independently; you do not have to run all of them or in a specific order.*

- [**Demo 1 - The Basics**](./01-demo-basics/01-demo-basics.md): Kubernetes fundamentals. Set up a Pod, Deployment and Service.
- [**Demo 2 - Scheduling**](./02-demo-scheduling/02-demo-scheduling.md): Labels, taints, and tolerations. Learn how Kubernetes decides which node runs a workload.
- [**Demo 3 - Ingress with Traefik**](./03-demo-ingress/03-demo-ingress.md): Demostrates accessing apps via Ingress and setup of Ingress Controllers.
- [**Demo 4 - ConfigMaps and Secrets**](./04-configmaps-and-secrets/04-configmaps_and_secrets.md): Show how to pass configuration and sensitive data to Deployments.
- [**Demo 5 - Persistent Volumes**](./05-Persistent-Volumes/05-Persistent-Volumes.md): Create persistent volumes to be used by Pods.
- [**Demo 6 - Probes, Rolling Updates and Rollbacks**](./06-Updates-and-Probes/06-Updates-and-Probes.md): Create Pod health checks, apply rolling updates and practice rollbacks.