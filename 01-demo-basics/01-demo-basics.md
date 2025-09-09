# Demo 1 - The Basics (Pods, Deployments, Services)

> **Author’s notes:**  
>- I’ve kept the K3s setup as hardware-neutral as possible; Any Pi-specific bits are here mainly for reference.
>- I used Ubuntu Server 25.04, so commands use Debian/Ubuntu syntax.

## Learning Goals

- Understand what a Pod, Deployment, and Service are.
- Practice creating each from YAML manifests.
- See how Deployments add replication and self‑healing.
- See how Services expose Pods in a stable way.

## Prerequisites

- **Complete** [**Initial Setup Guide**](../00-initial-setup/initial-setup.md)
- Access to the terminal of the control node. I recommend using SSH.

## 1. Running a pod

A pod is the smallest runnable unit in Kubernetes. For this, we're going to use a very simple manifest yaml:

```yaml
apiVersion: v1  # Which API group/version to use.
kind: Pod       # Resource Type
metadata:
  name: nginx   # Unique resource name
# Pod Spec
spec:
  containers:
    - name: nginx
      image: nginx:latest   # Specifies the official nginx container
      ports:
        - containerPort: 80 # Port exposed inside the Pod
```
### Create the Pod

1. Connect to your Control Node. For me this is done via SSH

```bash
ssh <USER>@<CONTROL-NODE-IP-ADDRESS>
```

2. Pull the 00-simple_pod Manifest from the Github Repo and apply it to the cluster
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/10-simple_pod.yaml
```

3. Verify that the manifest was pulled, and that the pod has started
```bash
sudo kubectl get pods

# Sample Output:
NAME    READY   STATUS    RESTARTS   AGE
nginx   1/1     Running   0          2m15s
```

### Cleanup the Pod

1. Stop and delete the Nginx pod
```bash
sudo kubectl delete pod nginx
```

2. Verify the Pod has been removed.
```bash
sudo kubectl get pods

# Example return status
No resources found in default namespace.
```

### Pod Summary

If you hadn't picked up on it yet, there are some obvious issues with running a Pod like this:
- This Pod is running, but there is no way to access it, since no ports are forwarded or mapped.
- If this Pod was to crash, it would have to be manually restarted.

This is where a deployment and a service will help us. We'll tackle each one separately, starting with a deployment.

## 2. Running a Deployment

A Deployment manages Pods for you. It creates ReplicaSets, handles scaling, and replaces dead Pods. We've modifed our original Manifest yaml to include a deployment:

```yaml
apiVersion: apps/v1 # Changed to include Deployments
kind: Deployment    # Now it's a Deployment, not just a Pod
metadata:
  name: nginx       # Name of the Deployment object
# Define Deployment
spec:
  replicas: 3       # Specify the number of Pods to run
  selector:         # Which Pods this Deployment “owns”
    matchLabels:
      app: nginx        # MUST match template.metadata.labels exactly
  template:             # The Pod template the Deployment will create/manage
    metadata:
      labels:
        app: nginx
    # Define Pod (Original Pod from 00-simple_pod.yaml)
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
```

A Deployment fixes the following issues with our Simple Pod example:
- **Replication & self-healing**: K3s keeps 3 Pods alive. Kill one → it recreates.
- **Rollouts**: Changing the image triggers a rolling update (can monitor/undo).
- **Readiness vs liveness**: Ensures traffic only hits healthy Pods, and stuck containers get restarted.

### Running a Deployment

1. Connect to your Control Node if you haven't already. I recommend SSH.

```bash
ssh <USER>@<CONTROL-NODE-IP-ADDRESS>
```

2. Pull the 01-simple_deployment Manifest from the Github Repo and apply it to the cluster
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/11-simple_deployment.yaml
```

3. Verify that the manifest was pulled, and that the Deployment has started.
```bash
sudo kubectl get deploy,rs,pods -o wide

# Example Output:
NAME                    READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES         SELECTOR
deployment.apps/nginx   3/3     3            3           2m28s   nginx        nginx:latest   app=nginx

NAME                             DESIRED   CURRENT   READY   AGE     CONTAINERS   IMAGES         SELECTOR
replicaset.apps/nginx-96b9d695   3         3         3       2m28s   nginx        nginx:latest   app=nginx,pod-template-hash=96b9d695

NAME                       READY   STATUS    RESTARTS   AGE     IP           NODE      NOMINATED NODE   READINESS GATES      
pod/nginx-96b9d695-8qstw   1/1     Running   0          2m28s   10.42.1.5    rd-rp52   <none>           <none>
pod/nginx-96b9d695-9kh9k   1/1     Running   0          2m27s   10.42.2.4    rd-rp31   <none>           <none>
pod/nginx-96b9d695-9qwf5   1/1     Running   0          2m27s   10.42.0.14   rd-rp51   <none>           <none>
```

Each section of the output of this command shows us information about the Deployment:
- `deploy` - Shows us the overall status of the deployment. All three of our containers have started
- `rs` (replicaSet) - Shows us the current state of the replica set. In the above example, all 3 of our containers have been created and are in a state of `Ready`.
- `pods` - Shows us detailed information about each individual pod. You can see that a single pod has started on each of the three Nodes.

### Self-Healing

One of the cool features of Deployments is the self-healing. If a pod was to be deleted, the deployment would automatically start another pod.

1. Show currently running Pods
```bash
sudo kubectl get pods

# Example Output with Nginx Deployment
NAME                   READY   STATUS    RESTARTS   AGE
nginx-96b9d695-2gkj2   1/1     Running   0          5m
nginx-96b9d695-drmgp   1/1     Running   0          5m
nginx-96b9d695-hjk8j   1/1     Running   0          5m
```

2. Delete the pods
```bash
sudo kubectl delete pod -l app=nginx --wait=false
```

3. Show currently running Pods again
```bash
sudo kubectl get pods

# Example Output: Pod Names and age has changed
NAME                   READY   STATUS    RESTARTS   AGE
nginx-96b9d695-6m49c   1/1     Running   0          7s
nginx-96b9d695-dvf55   1/1     Running   0          7s
nginx-96b9d695-vnkmv   1/1     Running   0          7s
```

Notice on the output from step 3 that the Pod names and the age has changed. The Deployment automatically recreated the Pods when they were all deleted.

### Scaling

The final really cool feature of deployments is the ability to scale at a moment's notice.

1. Show currently running Pods
```bash
sudo kubectl get pods

# Example Output with Nginx Deployment
NAME                   READY   STATUS    RESTARTS   AGE
nginx-96b9d695-6m49c   1/1     Running   0          3m28s
nginx-96b9d695-dvf55   1/1     Running   0          3m28s
nginx-96b9d695-vnkmv   1/1     Running   0          3m28s
```

2. Scale the deployment
```bash
sudo kubectl scale deployment/nginx --replicas=4
```

3. Show currently running Pods again
```bash
sudo kubectl get pods

# Example Output: Now there are four Pods
nginx-96b9d695-6m49c   1/1     Running   0          3m44s
nginx-96b9d695-dvf55   1/1     Running   0          3m44s
nginx-96b9d695-k9s4z   1/1     Running   0          4s
nginx-96b9d695-vnkmv   1/1     Running   0          3m44s
```

### Cleanup the Deployment

1. Delete the Deployment
```bash
sudo kubectl delete deployment nginx
```

2. Verify the Pods have been removed.
```bash
sudo kubectl get pods

# Example return status
No resources found in default namespace.
```

### Deployment Summary

Deployments fix some of the issues we ran into with our single Pod setup:
- Pods can be scaled, and now feature high availability.
- If a Pod crashes, the Deployment will automatically schedule a new Pod.

However we still can't access these Pods; The ports are not forwarded. For that we will need to add a Service to our Deployment.

## 3. Running a Service

A Service provides a stable network entrypoint for a set of Pods. Without it, Pods’ IPs change constantly.

We need to modify our Manifest yaml one last time:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
# Define Deployment (Original Pod from 02-simple_deployment.yaml)
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    # Define Pod (Original Pod from 00-simple_pod.yaml)
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
---
# Define Service
apiVersion: v1
kind: Service       # Specify Service
metadata:
  name: nginx
spec:
  selector:
    app: nginx      # Matches our Spec Selector from Above
  ports:
  - port: 80        # Service Port (This is for internal cluster)
    targetPort: 80  # Port on the Pod to forward to
    nodePort: 30080 # External port on each Node
  type: NodePort    # Instruction to expose port on each Node to external LAN
```

### Run the Deployment with the Service

1. Connect to your Control Node if you haven't already. I recommend SSH.

```bash
ssh <USER>@<CONTROL-NODE-IP-ADDRESS>
```

2. Pull the 02-simple_deployment_with_service Manifest from the Github Repo and apply it to the cluster
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/12-simple_deployment_with_service.yaml
```

3. Verify that the manifest was pulled, and that the Deployment has started.
```bash
sudo kubectl get deploy

# Example Output:
NAME    READY   UP-TO-DATE   AVAILABLE   AGE
nginx   3/3     3            3           2m1s
```

4. Verify that the Service is running
```bash
sudo kubectl get svc nginx

# Example Output:
NAME    TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
nginx   NodePort   10.43.136.190   <none>        80:30080/TCP   2m29s
```

Our output says that we have exposed port 30080 outside the cluster, and it's mapped to port 80 on our Pods.

5. Test that the Deployment is working. This can be done in two ways.
- Open a web browser and navigate to `http://<ANY-NODES-IP-ADDRESS>:30080` and view the default Nginx welcome page.
- Use curl to confirm that the service is exposing the deployment:
```bash
curl http://<ANY-NODES-IP-ADDRESS>:30080
```

### Cleanup the Deployment and Service

1. Delete the Deployment
```bash
sudo kubectl delete deployment nginx
```

2. Delete the Service
```bash
sudo kubectl delete service nginx
```

3. Verify the Pods have been removed.
```bash
sudo kubectl get pods

# Example return status
No resources found in default namespace.
```

4. Verify the Service has been removed.
```bash
sudo kubectl get services | grep nginx

# Should return nothing
```

## Conclusion

You have now learned about the fundamentals of Kubernetes:
- **Pod** → one‑off container runtime. The most basic K8s unit.
- **Deployment** → controller that manages Pods at scale. Adds replication, healing, and updates.
- **Service** → stable access point that load balances traffic across Pods.

[**Click here to return to the Demos**](../README.md#demos)