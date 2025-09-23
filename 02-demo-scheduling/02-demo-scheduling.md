# Demo 2 - Scheduling (Labels, Taints, and Tolerations)

This demo teaches how Kubernetes decides where to place Pods, and how to control that behavior.

## Learning Goals

- Understand how to use labels and nodeSelectors to target workloads.
- See how taints prevent scheduling unless Pods explicitly tolerate them.
- Learn how to use tolerations to allow Pods onto tainted nodes.
- Practice affinity/anti-affinity rules to spread Pods across multiple nodes.

## Prerequisites

- **Complete** [**Initial Setup Guide**](../00-initial-setup/initial-setup.md)
- Access to the terminal of the control node. I recommend using SSH.

## Labelling Nodes

Let's say we have a setup like this:
- 10 Pods running NGINX for a website
- 10 Pods running Redis for caching

In Demo 1, we simply just exposed all the Pods. In this case, we don't really want to (or need to) expose the Redis Pods.

**So how do we tell Kubernetes to only expose a set of Pods?**

This is where Labels come in. Labels are simply a key/value pair that attach to a K8s object:

`hardware=pi5`, `role=worker`, `app=nginx`

By themselves, labels don’t change behavior. The power comes from how selectors use them:
- A Deployment selects Pods with a label, so it knows which Pods to manage.
- A Service selects Pods with a label, so it knows which Pods to send traffic to.
- A nodeSelector in a Pod spec looks for a label on Nodes, so it knows where it’s allowed to run.

### Add Labels to Nodes

> This part of the tutorial may differ if you used different hardware.

1. Add hardware labels to the different nodes

Label everything by Raspberry Pi Model.
For `rd-rp51`:
```bash
sudo kubectl label node rd-rp51 hardware=pi5
```

For `rd-rp52`:
```bash
sudo kubectl label node rd-rp52 hardware=pi5
```

For `rd-rp31`:
```bash
sudo kubectl label node rd-rp31 hardware=pi3
```

2. Verify Labels
```bash
sudo kubectl get nodes --show-labels | grep hardware
```

Notice that Kubernetes has already applied a number of default labels to each node. We can see our custom `hardware` label has been added to this list:

```bash
# Example labels for rd-rp31
beta.kubernetes.io/arch=arm64, beta.kubernetes.io/instance-type=k3s, beta.kubernetes.io/os=linux, hardware=pi3, kubernetes.io/arch=arm64, kubernetes.io/hostname=rd-rp31, kubernetes.io/os=linux, node.kubernetes.io/instance-type=k3s
```

- **Labels are additive**: when you add `hardware=pi3`, it joins the existing list of labels, it doesn’t remove defaults.
- You can change an existing label by re-running the command with `--overwrite`.
- Using meaningful keys like `hardware`, `role`, or `env` is a best practice.
- Common real-world labels include things like `region=us-west`, `zone=us-west-1a`, `env=production`, or `disk=ssd`.

### Scheduling with nodeSelector

Now that our Nodes have some labels, we can use them to tell Kubernetes where to place Pods. To that end, we will use a `nodeSelector` in our pod deployment Manifest:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
# Define Deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    # Define Pod
    spec:
      nodeSelector:
        hardware: "pi5"   # Only schedule on nodes labeled hardware=pi5
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
```

1. Connect to your Control Node. For me this is done via SSH

```bash
ssh <USER>@<CONTROL-NODE-IP-ADDRESS>
```

2. Pull the 20-nodeSelector_with_labels Manifest from the Github Repo and apply it to the cluster
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/20-nodeSelector_with_labels.yaml
```

3. Verify that the manifest was pulled, and that the pod has started
```bash
sudo kubectl get pods -o wide
```

Example Output:
```bash
NAME                     READY   STATUS    RESTARTS   AGE   IP            NODE      NOMINATED NODE   READINESS GATES
nginx-568d477586-2fvr9   1/1     Running   0          14m   10.42.1.156   rd-rp52   <none>           <none>
nginx-568d477586-2jsgf   1/1     Running   0          14m   10.42.0.171   rd-rp51   <none>           <none>
nginx-568d477586-hxs4f   1/1     Running   0          14m   10.42.1.155   rd-rp52   <none>           <none>
```

In this output, notice that there are no Pods on rd-rp31. This is because of the `hardware=pi5` label we added earlier. Even though we set `replicas: 3`, the scheduler only placed Pods on the nodes that matched the label (`rd-rp51` and `rd-rp52`).

### Cleanup the Deployment

1. Stop and delete the Nginx Deployment
```bash
sudo kubectl delete deployment nginx
```

2. Verify the Pods have been removed
```bash
sudo kubectl get pods
```
Example Output:
```bash
No resources found in default namespace.
```

3. Remove the labels from each Node.

For `rd-rp51`:
```bash
sudo kubectl label node rd-rp51 hardware-
```

For `rd-rp52`:
```bash
sudo kubectl label node rd-rp52 hardware-
```

For `rd-rp31`:
```bash
sudo kubectl label node rd-rp31 hardware-
```
### Labels Summary

This section showed how to use a nodeSelector to restrict scheduling to certain nodes. By deleting the Deployment now, we’ll have a clean slate for the next section (taints and tolerations).

### Taints and Tolerations

In the last two sections, we demonstrated how to use labels and nodeSelectors to invite Pods to specific nodes. We can also do the opposite, and tell Kubernetes where **not** to put Pods using taints.

#### A common use case with K8s is to taint the control node(s). In our setup, we will use the following command to taint the `rd-rp51` node.
```bash
sudo kubectl taint nodes rd-rp51 dedicated=control:NoSchedule
```

#### Verify the taint applied using the following commands:
View taints on `rd-rp51`:
```bash
sudo kubectl describe node rd-rp51 | grep Taints
```

Example Output:
```bash
Taints:             dedicated=control:NoSchedule
```

Tainting Nodes forces Pods to have to "opt-in" in order to be scheduled on a tainted node.

#### Pull the 11-simple_deployment Manifest from demo 1 and apply it to the cluster
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/11-simple_deployment.yaml
```

#### Verify the Pods
```bash
sudo kubectl get pods -o wide
```

Example Output:
```
NAME                   READY   STATUS    RESTARTS   AGE     IP           NODE      NOMINATED NODE   READINESS GATES
nginx-96b9d695-r64xt   1/1     Running   0          2m15s   10.42.1.17   rd-rp52   <none>           <none>
nginx-96b9d695-stclr   1/1     Running   0          2m15s   10.42.1.16   rd-rp52   <none>           <none>
nginx-96b9d695-ts5md   1/1     Running   0          2m15s   10.42.2.10   rd-rp31   <none>           <none>
```

Notice that there are no Pods running on `rd-rp51`. This is common practice in production, to taint certain nodes that are critical to the cluster. This prevents them from getting overloaded and taking the entire cluster down.

#### Delete the Deployment
```bash
sudo kubectl delete deployment nginx
```

### Adding Tolerations

Let's modify the Manifest to allow the Pods to tolerate a tainted node. In this example, we want to allow Pods to be schduled on the tainted control node, `rd-rp51`.

The Manifest below is just the 11-simple_deployment.yaml with a new tolerations section in the spec section:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
# Define Deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    # Define Pod
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
      # New Tolerations Section
      tolerations:
        - key: "dedicated"
          operator: "Equal"
          value: "control"
          effect: "NoSchedule"
```

#### Pull the 22-nodeSelector_with_tolerations Manifest from the Github Repo and apply it to the cluster:
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/20-nodeSelector_with_tolerations.yaml
```

#### Verify the Pods
```bash
sudo kubectl get pods -o wide
```

Example Output:
```bash
NAME                     READY   STATUS    RESTARTS   AGE   IP           NODE      NOMINATED NODE   READINESS GATES
nginx-7b8c8545f6-9ktcd   1/1     Running   0          9s    10.42.0.21   rd-rp51   <none>           <none>
nginx-7b8c8545f6-k2brz   1/1     Running   0          9s    10.42.2.13   rd-rp31   <none>           <none>
nginx-7b8c8545f6-nm68x   1/1     Running   0          9s    10.42.1.21   rd-rp52   <none>           <none>
```

As you can see, the deployment can schedule Pods on `rd-rp51`, despite it being a tainted node.

### Cleanup the Deployment

#### Delete the Deployment:
```bash
sudo kubectl delete deployment nginx
```

#### Remove the taints from the nodes so they return to normal:
```bash
sudo kubectl taint nodes rd-rp51 dedicated=control:NoSchedule-
```

### Taints and Tolerations Summary

- Taints block scheduling on a node unless a Pod tolerates them.
- Tolerations are how Pods “opt in” to tainted nodes.
- This mechanism is often used to reserve nodes for special workloads (e.g., control-plane, GPU nodes, or dedicated hardware).

## Affinity and Anti-Affinity

At this point, we've learned how to control where Kubernetes places Pods on Nodes using Labels and Taints, but there is a third way that provides much finer control.

Affinity rules provide similar functionality, but give much finer control. For example, what if we want nodes to ***prefer*** the Pi5s, but not be completely barred from using the Pi3? Affinity would allow us to do this.

In this example, we've taken that same Nginx example from Demo 1, and we've modified it to use Affinity/Anti-Affinity:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
# Deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    # Pod
    spec:
      # Prefer (not require) Pi 5s
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: hardware
                    operator: In
                    values: ["pi5"]
        # Force replicas onto different nodes
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: nginx
              topologyKey: kubernetes.io/hostname
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
```
This new `affinity` section has two parts:
- `nodeAffinity`: This section tells the Deployment to prefer any node with a `hardware=pi5` label.
- `podAntiAffinity`: At the same time, this section tells the Deployment to avoid putting Pods all the same Node.

> While these two sections seem to cancel each other out, Anti-Affinity will show how Affinity will prefer and spread the containers across all Nodes.

#### Apply labels to the Nodes again
Label everything by Raspberry Pi Model.
For `rd-rp51`:
```bash
sudo kubectl label node rd-rp51 hardware=pi5
```

For `rd-rp52`:
```bash
sudo kubectl label node rd-rp52 hardware=pi5
```

For `rd-rp31`:
```bash
sudo kubectl label node rd-rp31 hardware=pi3
```

#### Pull the 22-affinity_and_anti_affinity Manifest from the Github Repo and apply it to the cluster
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/22-affinity_and_anti_affinity.yaml
```

#### Verify that the manifest was pulled, and that the pod has started
```bash
sudo kubectl get pods -o wide
```

Example Output:
```bash
NAME                   READY   STATUS              RESTARTS   AGE   IP            NODE      NOMINATED NODE   READINESS GATES 
nginx-f7dc7797-4xlnj   1/1     Running             0          4s    10.42.0.177   rd-rp51   <none>           <none>
nginx-f7dc7797-l7vhc   1/1     Running             0          4s    10.42.1.167   rd-rp52   <none>           <none>
nginx-f7dc7797-m28gd   0/1     ContainerCreating   0          4s    <none>        rd-rp31   <none>           <none>
```

As we can see, the Pods were applied to all the Nodes in the cluster because the Anti-Affinity forces one Pod per Node, despite the Affinity preferring the `rd-rp51` and `rd-rp52` nodes.

### Cleanup the Deployment

#### Delete the Deployment
```bash
sudo kubectl delete deployment nginx
```

#### Verify that the Pods have been removed
```bash
sudo kubectl get pods

# Example return status
No resources found in default namespace.
```

### Affinity Summary

- Affinity allows Pods to prefer certain nodes without strictly requiring them (e.g., Pi 5s over Pi 3).
- Anti-Affinity ensures Pods are spread out, preventing multiple replicas from running on the same node.
- Together, these rules give you fine-grained control over scheduling, balancing performance (favoring Pi 5s) with resilience (spreading across all nodes).

## Conclusion

In this demo, you learned how Kubernetes decides where Pods are scheduled in a cluster:
- **Labels** → Metadata that describe nodes.
- **nodeSelectors** → Restrict Pods to only nodes that match specific labels.
- **Taints & Tolerations** → Prevent Pods from running on a node unless they explicitly “opt in.”
- **Affinity & Anti-Affinity** → Provide fine-grained scheduling rules to prefer certain nodes and spread Pods across the cluster.

With these tools, you can shape the placement of your workloads to match your hardware, protect critical nodes, and improve resilience.

[**Click here to return to the Demos**](../README.md#demos)