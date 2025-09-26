# Demo 5 - Persistent Volumes

In this demo, we'll be adding persistent storage to our nginx app using the default `local-path` StorageClass. We'll request storage with a PVC, mount it in a Pod, write a test file to the storage, and show that the data persists across Pods.

## Learning Goals

- Understand the parts of Persistent Volume resources. (`StorageClass`, `PVC`, `PV`, and `volumeMount`)
- How Kubernetes provisions storage dynamically.
- Show node-local behavior.
- Explore the differences between local-path and distributed storage.

## Prerequisites

- **Complete** [**Initial Setup Guide**](../00-initial-setup/initial-setup.md)
- Access to the terminal of the control node. I recommend using SSH.

## Setting up our Manifest

Let's start by talking about the parts required to create a Persistent Volume:
- **StorageClass**: A template that tells Kubernetes how to provision storage. This abstracts the low-level details, and allows Apps to more consistently request storage.
- **PersistentVolumeClaim (PVC)**: A request for storage made by a Pod that specifies the size, access mode, and StorageClass to use.
- **PersistentVolume (PV)**: This is where the data is physically stored. It can be a directory on a Node, a block device, a network share, etc. It has rules for capacity, access mode, and lifecycle.
- **volumeMount**: This is a mountpoint inside the Pod itself. Instructions are provided in a Pod spec that attaches a volume into a container at a specific filesystem path.

So with that all in mind, let's modify our 11-simple-deployment Manifest to create a Persistent Volume:
```yaml
# New PVC
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo5-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
---
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      # NEW - Creates a small index.html inside the volume
      initContainers:
        - name: init-write
          image: busybox
          command: ["/bin/sh","-c"]
          args:
            - 'mkdir -p /data && printf "<h1>Demo 05</h1><p>Created: $(date)</p>\n" > /data/index.html'
          volumeMounts:
            - name: data
              mountPath: /data
      # Define Pod
      containers:
        - name: nginx
          image: nginx
          volumeMounts:
            - name: data
              mountPath: /usr/share/nginx/html
      # NEW - Define the volumes
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: demo5-pvc
```

> Note that we have also added an initContainer that creates a small `index.html` file on initialization. `initContainer` is not part of this demo, it just simplifies the instructions.

## Apply Manifest to the Cluster
1. First, apply the manifest to the Cluster:
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/50-persistent-volume.yaml
```

2. Verify that the PVC is Bound:
```bash
sudo kubectl get pvc demo5-pvc
```

Example Output:
```bash
# We want to see status Bound
NAME        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
demo5-pvc   Bound    pvc-a4e97e26-4f09-4d89-aea5-58a5b6283f2b   1Gi        RWO            local-path     <unset>
    4m33s
```

3. Verify that the PV Exists:
```bash
sudo kubectl get pv
```

Example Output:
```bash
# Again, we want to see status Bound
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM               STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
pvc-a4e97e26-4f09-4d89-aea5-58a5b6283f2b   1Gi        RWO            Delete           Bound    default/demo5-pvc   local-path     <unset>                          5m37s
```

4. Verify the Pod is running:
```bash
sudo kubectl get pods
```

Example Output:
```bash
NAME                     READY   STATUS    RESTARTS   AGE
nginx-5d44fb9c8b-727cc   1/1     Running   0          7m23s
```

## Port Forward the Pod
1. Run the following to port forward the Pod:
```bash
sudo kubectl port-forward deploy/nginx 8080:80
```

2. Open a new terminal to the control node, and run `curl`:
```bash
curl -s http://127.0.0.1:8080 | sed -n '1,5p'
```

Example Output:
```bash
# This is the html from the file we created with the initContainer
<h1>Demo 05</h1><p>Created: Wed Sep 24 21:58:44 UTC 2025</p>
```

## Delete the Pod and Demostrate Persistence

Now that we can see the persistent volume working, we will attempt to delete the Pod and show that the `index.html` file is still available.

1. Delete the Pod:
> See [Demo 1](../01-demo-basics/01-demo-basics.md#self-healing) for more about self-healing in deployments.
```bash
sudo kubectl delete pod -l app=nginx
```

2. Restart the Port Forwarding:
```bash
sudo kubectl port-forward deploy/nginx 8080:80
```

3. In a second terminal session to the control node, and run `curl` again:
```bash
curl -s http://127.0.0.1:8080 | sed -n '1,5p'
```

Example Output:
```bash
# This is the html from the file we created with the initContainer
<h1>Demo 05</h1><p>Created: Wed Sep 24 21:58:44 UTC 2025</p>
```

**Congratulations!** You have successfully setup a Persistent Storage Volume on the cluster.

## Cleanup

1. Delete the Deployment
```bash
sudo kubectl delete deploy nginx
```

2. Delete the Service
```bash
kubectl delete service nginx-persistent
```

3. Delete the Claim
```bash
sudo kubectl delete pvc demo5-pvc
```

4. Verify that everything is gone.
```bash
sudo kubectl get deploy,pod,pvc,pv # Should return "No resources found"
```
> *Note* - This may take a few minutes to apply.

## Distributed Storage
Local-path volumes are great for single Node setups, but they create problems if you need data to exist across multiple Nodes. Because the data is stored on a single Node’s disk, if a Pod is rescheduled from `rd-rp52` to `rd-rp31`, the Pod will no longer have access to the files it wrote when it was running on `rd-rp52`.

This is where **Distributed Storage** comes in. Distributed storage adds resilience and replication to persistent storage. Instead of the data existing on only one node, it is automatically replicated in the background to other participating nodes and reattached to a Pod when rescheduling occurs. This provides highly available storage and allows Pods to move freely across the cluster without worrying about which node holds the data.

A few common Distributed Storage options:
- [**Longhorn**](https://longhorn.io/)
- [**Ceph**](https://ceph.io/en/)
- [**OpenEBS**](https://openebs.io/)

### Differences between Local-Path and Distributed Storage
|**Local-path**|**Distributed Storage**|
|-|-|
| Directory on disk of a single Node | Replicated across multiple Nodes |
| Pods must run on the same Node | Pods can run on any Node |
| If Node fails, data is unavailable | Data "self-heals" and volume reattaches |
| Only a single Pod can Read/Write (RWO mode) | Allows for simultaneous Read/Writes (RWX mode) |
| Built-In to K3s | Requires extra controllers and monitoring |
| Best for ephemeral apps, short-lived demos | Best for production workloads |

> *Distributed Storage was omitted from this demo because it generally requires more overhead than a Raspberry Pi can handle.*

## Conclusion

In this demo, you learned how Kubernetes provides persistent storage using PersistentVolumeClaims (PVCs), how PVCs bind to PersistentVolumes (PVs) provisioned by a StorageClass.

In this demo, you saw that:
- Pods are ephemeral, but can have persistent data. Despite deleting a Pod, the `index.html` was served because it was stored on the PVC's volume.
- The built-in `local-path` StorageClass in K3s is easy, but the data is stored only on a single Node. If the Node goes down, so does the data.
- Distributed storage systems (Longhorn, Ceph, or OpenEBS) address this limitation by replicating volumes across multiple Nodes, and allow Pods to be scheduled across all participating Nodes.

[**Click here to return to the Demos**](../README.md#demos)