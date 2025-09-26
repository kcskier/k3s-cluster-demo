# Demo 6 - Probes, Rolling Updates and Rollbacks

In a production environment, it’s not enough to just run Pods—you need to keep them healthy, update them safely, and recover quickly if something goes wrong.  
This demo shows how to add **readiness** and **liveness** probes, perform a **rolling update**, deliberately break things with a bad patch, and finally **roll back** to a working state.

## Learning Goals

- Understand the difference between Readiness and Liveness probes.  
- Learn how to perform a rolling update of a Deployment.  
- Use `kubectl rollout status` to monitor update progress.  
- Recognize what happens when a Deployment becomes unhealthy.  
- Roll back quickly to a known good state using `kubectl rollout undo`.  

## Prerequisites

- **Complete** [**Initial Setup Guide**](../00-initial-setup/initial-setup.md)
- Access to the terminal of the control node. I recommend using SSH.

## Setting up our Manifest

Per usual, we start by modifying to our 11-simple-deployment Manifest:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  # NEW - change-cause will be used later for tracking changes
  annotations:
    kubernetes.io/change-cause: "Initial deploy"
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
          image: nginx:1.27.1-alpine   # pin version for demo
          ports:
            - containerPort: 80
          # NEW - Readiness Probe gates traffic until Pod is ready
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 3
          # NEW - Liveness Probe restarts container if it becomes unhealthy
          livenessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 10

```

There are two new items added at the bottom:
- `readinessProbe`: Checks to see if the container is ready to handle traffic. In the event that the probe fails, the Pod will be marked *NotReady* and removed from Service endpoints. This will prevent requests from being routed to the Pod before it's ready, or if the Pod becomes unable to handle traffic.
- `livenessProbe`: This probe checks if the container stays alive, and if the Pod needs to be restarted. If this probe fails repeatedly, Kubernetes will automatically kill and restart the Pod. This is useful if an app crashes, or if a restart is the only fix.

## Apply Manifest to the Cluster
Apply our demo Manifest to the Cluster:
```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/60-rolling_updates.yaml
```

Verify that the Deployment has applied:
```bash
kubectl get deploy,pods
```

Example Output:
```bash
NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx   3/3     3            3           6m41s

NAME                         READY   STATUS    RESTARTS      AGE
pod/nginx-6b5c4f487f-5mghz   1/1     Running   4 (22s ago)   2m23s
pod/nginx-6b5c4f487f-c5b7j   1/1     Running   3             2m38s
pod/nginx-6b5c4f487f-gvrxg   1/1     Running   4 (20s ago)   2m50s
```

## Apply a rolling update
Currently, our Deployment is running the `nginx:1.27.1-alpine` image. We would like to rollout `nginx:1.27.2-alpine` to all our Pods.

Set the image on the deployment:
```bash
kubectl set image deploy/nginx nginx=nginx:1.27.2-alpine
```

Annotate a `change-cause` to the deployment:
```bash
kubectl annotate deploy/nginx kubernetes.io/change-cause="Good update to 1.27.2-alpine"
```

See the live status of the rollout:
```bash
kubectl rollout status deploy/nginx
```

Example Output:
```bash
Waiting for deployment "nginx" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "nginx" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "nginx" rollout to finish: 1 old replicas are pending termination...
deployment "nginx" successfully rolled out
```

## Demonstrate Readiness and Liveness Probes (Push a Bad Update)
Let's *"accidentally"* push a bad patch to the Deployment to simulate a crashed app. This patch effectively forces our Readiness and Liveness Probes to check for something that does not exist, which will break our Deployment:

```bash
kubectl patch deploy/nginx --type='json' -p='[
  {"op":"add","path":"/metadata/annotations/kubernetes.io~1change-cause","value":"Breaking Change"},
  {"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/nope"},
  {"op":"replace","path":"/spec/template/spec/containers/0/livenessProbe/httpGet/path","value":"/nope"}
]'
```

Run the rollout command with  `--timeout=30s`. This will show that our deployment is not starting properly:
```bash
kubectl rollout status deploy/nginx --timeout=30s
```

Example Output:
```bash
Waiting for deployment "nginx" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "nginx" rollout to finish: 1 out of 3 new replicas have been updated...
error: timed out waiting for the condition
```

(Optional) You can watch the Pods crash and restart in realtime. Notice that the `Restart` counter in increasing thanks to that Liveness Probe:
```bash
kubectl get pods -l app=nginx -w
```

(Optional) You can also run the `describe` command to view details on Pods, including the logs that show the Liveness and Readiness probe failures:
```bash
kubectl describe pod -l app=nginx | grep -A3 -Ei "Readiness probe failed|Liveness probe failed"
```

## Rollback the Deployment
Now that we've confirmed that our Deployment is broken, we need to get it back to a working state.

Kubernetes has the `rollback` feature. Rollbacks allow us to undo changes made by patches. This is especially helpful in a production environment where you may not have time to write a patch and just need to get the Deployment back up and running ASAP.

We can view the history of the patches to the Deployment:
```bash
kubectl rollout history deploy/nginx
```

Thanks to our annotations to the `Change-Cause` field, we can clearly see the changes we've made:
```bash
deployment.apps/nginx 
REVISION  CHANGE-CAUSE
1         Initial deploy
2         Good update to 1.27.2-alpine
3         Breaking Change
```

(Optional) View details on a particular revision
```bash
kubectl rollout history deploy/nginx --revision 2
```

Since the Liveness and Readiness checks are failing, we can simply use the undo command to rollback to the Deployment's last working state:
```bash
kubectl rollout undo deploy/nginx
```

(Optional) If we wanted to, we could also specify a specific revision to rollback to:
```bash
kubectl rollout undo deploy/nginx --to-revision=3
```

View current status of the rollout:
```bash
kubectl rollout status deploy/nginx
```

Finally, verify that the deployment has come up successfully:
```bash
kubectl get deploy,pods
```

## Cleanup
Delete the Deployment:
```bash
kubectl delete deploy nginx
```

Verify that the Deployment was removed:
```bash
kubectl get deploy,pods
```

Example Output:
```bash
No resources found in default namespace.
```

## Conclusion

In this demo, you enhanced a simple Deployment with health checks and learned how Kubernetes manages application updates and failures.

- **Readiness and Liveness Probes** allows a Pod to be used only when healthy, and automatically restarts in the event that the Pod is unhealthy.
- **Rolling updates** let you safely patch a Deployment without downtime.  
- **Rollbacks** provide a quick recovery path when a change causes failures, restoring the Deployment to a known good state.

[**Click here to return to the Demos**](../README.md#demos)