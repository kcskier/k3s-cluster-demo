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
- A cluster with at least 2 worker nodes (Here: `rd-rp51`, `rd-rp52`, `rd-rp31`).

## 1 - Labelling Nodes

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

### 1. Add Labels to Nodes

> This part of the tutorial may differ if you used different hardware.

1. Add hardware labels to the different nodes
```bash
# Label the Pi 5 hardware
sudo kubectl label node rd-rp51 hardware=pi5
sudo kubectl label node rd-rp52 hardware=pi5

# label the Pi 3b+
sudo kubectl label node rd-rp31 hardware=pi3
```

2. Verify Labels
```bash
sudo kubectl get nodes --show-labels
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

### 2. Scheduling with nodeSelector

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

# Sample Output:
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

# Example return status
No resources found in default namespace.
```

### Labels Summary

This section showed how to use a nodeSelector to restrict scheduling to certain nodes. By deleting the Deployment now, we’ll have a clean slate for the next section (taints and tolerations).

### 3. Taints and Tolerations

In the last two sections, we demonstrated how to use labels and nodeSelectors to invite Pods to specific nodes. We can also do the opposite, and tell Kubernetes where **not** to put Pods using taints.

1. A common use case with K8s is to taint the control node(s). In our setup, we will use the following command to taint the `rd-rp51` node.
```bash
sudo kubectl taint nodes rd-rp51 dedicated=control:NoSchedule
```

2. For our demonstration, we will also taint the `rd-rp52` node.
```bash
sudo kubectl taint nodes rd-rp52 dedicated=demo:NoSchedule
```

3. Verify the taints applied using the following commands:
```bash
sudo kubectl describe node rd-rp51 | grep Taints
sudo kubectl describe node rd-rp52 | grep Taints

# Example outputs
# rd-rp51
Taints:             dedicated=control:NoSchedule
# rd-rp52
Taints:             dedicated=demo:NoSchedule
```

Tainting Nodes forces Pods to have to "opt-in" in order to be scheduled on a tainted node.

4. Pull the 20-nodeSelector_with_labels Manifest from the Github Repo and apply it to the cluster
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/20-nodeSelector_with_labels.yaml
```

5. Verify the Pods
```bash
sudo kubectl get pods

# Example Output
NAME                     READY   STATUS    RESTARTS   AGE
nginx-568d477586-6krk8   0/1     Pending   0          12s
nginx-568d477586-759sf   0/1     Pending   0          12s
nginx-568d477586-fbhh4   0/1     Pending   0          12s
```

Notice that all of the Pods have a status of `Pending`. This is because the Pi 5s are tainted and the Pods don’t tolerate those taints.

6. Delete the Deployment
```bash
sudo kubectl delete deployment nginx
```

### Adding Tolerations

Let's modify the Manifest to allow the Pods to tolerate a tainted node. Remember that we tainted `rd-rp51` with `dedicated=demo:NoSchedule`. Below we’ve added a toleration for that taint:
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
      nodeSelector:
        hardware: "pi5"   # Still only allowing pi5s
      tolerations:              # New tolerations section
        - key: "dedicated"    # Matches the taint on rd-rp52
          operator: "Equal"
          value: "demo"
          effect: "NoSchedule"
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
```

7. Pull the 21-nodeSelector_with_taints Manifest from the Github Repo and apply it to the cluster:
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/21-nodeSelector_with_taints.yaml
```

5. Verify the Pods
```bash
sudo kubectl get pods -o wide

# Example Output
nginx-84bccc8cd5-6kcdt   1/1     Running   0          65s   10.42.1.157   rd-rp52   <none>           <none>
nginx-84bccc8cd5-76kh8   1/1     Running   0          64s   10.42.1.158   rd-rp52   <none>           <none>
nginx-84bccc8cd5-st7cb   1/1     Running   0          64s   10.42.1.159   rd-rp52   <none>           <none>
```

Now instead of the status of the Pods all saying `Pending`, we can see that each of them have a `Running` status and are on the `rd-rp52` Node.

### Cleanup the Deployment

1. Delete the Deployment:
```bash
sudo kubectl delete deployment nginx
```

2. Remove the taints from the nodes so they return to normal:
```bash
# rd-rp51
sudo kubectl taint nodes rd-rp51 dedicated=control:NoSchedule-

# rd-rp52
sudo kubectl taint nodes rd-rp52 dedicated=demo:NoSchedule-
```

### Taints and Tolerations Summary

- Taints block scheduling on a node unless a Pod tolerates them.
- Tolerations are how Pods “opt in” to tainted nodes.
- This mechanism is often used to reserve nodes for special workloads (e.g., control-plane, GPU nodes, or dedicated hardware).

## 4. Affinity and Anti-Affinity

At this point, we've leared how to control where Kubernetes places Pods on Nodes using Labels and Taints, but there is a third way that provices much finer control.

Affinity rules provide similar functionality, but give much finer control. For example, what if we want nodes to ***prefer*** the Pi5s, but not be completely barred from using the Pi3? Affinity would allow us to do this.

In this example, we've taken that same Nginx example from Demo 1, and we've modified it to use Affinity/Anti-Affinity:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
# Deployment
spec:
  replicas: 5
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

1. Pull the 23-affinity_and_anti_affinity Manifest from the Github Repo and apply it to the cluster
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/23-affinity_and_anti_affinity.yaml
```

2. Verify that the manifest was pulled, and that the pod has started
```bash
sudo kubectl get pods -o wide

# Sample Output:
NAME                   READY   STATUS              RESTARTS   AGE   IP            NODE      NOMINATED NODE   READINESS GATES 
nginx-f7dc7797-4xlnj   1/1     Running             0          4s    10.42.0.177   rd-rp51   <none>           <none>
nginx-f7dc7797-l7vhc   1/1     Running             0          4s    10.42.1.167   rd-rp52   <none>           <none>
nginx-f7dc7797-m28gd   0/1     ContainerCreating   0          4s    <none>        rd-rp31   <none>           <none>
```

As we can see, the Pods were applied to all the Nodes in the cluster because the Anti-Affinity forces one Pod per Node, despite the Affinity preferring the `rd-rp51` and `rd-rp52` nodes.

### Cleanup the Deployment

1. Delete the Deployment
```bash
sudo kubectl delete deployment nginx
```

2. Verify that the Pods have been removed
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