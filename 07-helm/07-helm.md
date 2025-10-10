# Demo 7 - Helm and Kubernetes Package Managers

In this demo, you will learn how to use **Helm**. If you're familiar with `apt`, `snap`, or `yum`, Helm attempts to solve the same problem, but for Kubernetes clusters.

Helm simplifies installing, upgrading, and removing applications by providing packages of manifests and configuration into reusable charts. In this demo, we will install Helm, add a public chart repository, deploy an Nginx web server, and access it externally using a NodePort.

## Learning Goals

- Understand what Helm is and how to use it.
- Install Helm on the cluster.
- Deploy and manage an application using Helm.
- Access the application from your desktop via NodePort.

## Prerequisites

- **Complete** [**Initial Setup Guide**](../00-initial-setup/initial-setup.md)
- Access to the terminal of the control node. I recommend using SSH.

## 1. Install Helm

Start by installing Helm on `rd-rp51` using Helm's setup script:
```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Verify that Helm is installed:
```bash
helm version
```

(Optional) Set up helm autocompletion:
```bash
helm completion bash | sudo tee /etc/bash_completion.d/helm >/dev/null
```

## 2. Add a Chart Repository

Helm uses `charts` from Helm `repositories`. For our example, we'll use Bitnami's Nginx chart.

To do that, we need to add the Bitnami repository to Helm:
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

Update the Helm repositories:
```bash
helm repo update
```

Verify that the repository is there:
```bash
helm repo list
```

## 3. Deploy a Chart

Now we will install the Nginx chart from the repository:
```bash
helm install web bitnami/nginx --set service.type=NodePort
```

Verify the deployment. You can list the Helm deployment with:
```bash
helm list
```

You can also use the usual commands to see the Pods and Services. Run the following, taking note of the port number.
```bash
kubectl get pods,svc
```

## 4. Access Nginx from your computer

Using the port number from the `kubectl get svc` command in the last step, open a web browser on your computer and navigate to the address of any Node. You should see the Nginx default page:
```text
http://<NODE_IP_ADDRESS>:<PORT>
```

## 5. Other Useful Helm Features (status, history, scaling)

### Status

You can view the status of your chart, which provides helpful information and recommendations, by running:
```bash
helm status web
```

### History

You can also view the revision history of our Nginx deployment. Run the following to see it: (There will only be one entry)
```bash
helm history web
```

### Scaling

We can also scale the Deployment using Helm.

First, show the current number of Pods:
```bash
kubectl get deploy,pods # There should only be one
```

Scale using Helm:
```bash
helm upgrade web bitnami/nginx --set replicaCount=2
```

Check the number of Pods again:
```bash
kubectl get deploy,pods # Now there are two
```

## Cleanup

Cleanup is a single command:
```bash
helm uninstall web
```

Verify the Pods are gone:
```bash
helm list # Should return an empty list
```

## Conclusion

In this demo, you installed Helm, added a Helm repository, and deployed a chart. Unlike previous demos where we had to make manifests ourselves, Helm simplifies deployments and bundles pre-made manifests and configurations into versioned packages.

- **Helm** is the package manager for Kubernetes.
- **Charts** bundle manifests and configurations in versioned packages.
- **Repositories** host pre-built charts for common apps.
- Basic `helm` commands like `install`, `upgrade`, `status`, and `uninstall` simplify deployment management and lifecycle.

[**Click here to return to the Demos**](../README.md#demos)