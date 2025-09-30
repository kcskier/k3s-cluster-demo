# Demo 4 - ConfigMaps and Secrets

In this demo we explore ConfigMaps and Secrets, two Kubernetes objects used to separate configuration data from application code. ConfigMaps store non-sensitive settings such as environment variables or config files, while Secrets store sensitive data like passwords and API keys.

## Learning Goals

- Create a ConfigMap and Secret
- Inject them into a Deployment as an `env` variables and mounted files
- Render a simple web page using a ConfigMap value
- Safely access Secret data inside a Pod

## Prerequisites

- **Complete** [**Initial Setup Guide**](../00-initial-setup/initial-setup.md)
- Access to the terminal of the control node. I recommend using SSH.

## 1. Create and Deploy

Similar to the other demos, we will start by creating a simple deployment based off of demo 1. Environmental variables are just simply keypairs:

```
ENV_VAR_NAME="Hello World!"
```

The difference between ConfigMaps and Secrets are how the Cluster stores them.
- `ConfigMaps` just store the value in plaintext
- `Secrets` store values in `base64-encoded strings`. In other words, these values are protected.

#### 1. Give the Cluster a Secret and a ConfigMap

You can define Secrets and ConfigMaps in files, but for our example we'll just directly apply them to the Cluster:

Apply a ConfigMap
```bash
kubectl create configmap demo4-config --from-literal=WELCOME_MESSAGE="Hello from ConfigMap!" 
```

Apply a Secret
```bash
kubectl create secret generic demo4-secret --from-literal=DB_PASSWORD="Its_a_Secret!!!"
```

Creating `ConfigMaps` and `Secrets` are helpful when you want to add variables and keep them separate from your code. These values are stored in the Cluster, which is generally a more secure way to store them. `Secrets` take it a step further by encrypting the value.

#### 2. Create a Deployment

We will modify the simple deployment yaml to instruct the container pull a variable and secret:

```yaml
# Based on 11-simple_deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
# Define Deployment
spec:
  replicas: 1       # We only need one Pod for this demo
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
          # NEW - Instruct the container to pull the environment variable
          envFrom:
            - configMapRef:
                name: demo4-config
          # NEW - Define the Secret
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: demo4-secret
                  key: DB_PASSWORD
```

#### 3. Apply the Deployment to the Cluster

```bash
kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/40-configmaps-secrets.yaml
```

#### 4. Verify the deployment has started
```bash
kubectl get pods -o wide # Should show one pod with status "RUNNING"
```

## 2. Print the values from inside the container

Now we need to enter the Pod and confirm that it can get the variable and secret.

The following is a quick bash script that will locate the pod and print the values.

```bash
POD=$(kubectl get pod -l app=nginx -o jsonpath='{.items[0].metadata.name}') &&
kubectl exec -it "$POD" -- /bin/sh -lc 'echo "WELCOME_MESSAGE=$WELCOME_MESSAGE"; echo "DB_PASSWORD=$DB_PASSWORD"'
```

Example output
```bash
WELCOME_MESSAGE=Hello from ConfigMap!
DB_PASSWORD=Its_a_Secret!!!
```

## 3. Cleanup

#### 1. Delete the Deployment
```bash
kubectl delete deployment nginx
```

#### 2. Delete the ConfigMap
```bash
kubectl delete configmap demo4-config
```

#### 3. Delete the Secret
```bash
kubectl delete secret demo4-secret
```

## Conclusion

In this demo, you connected configuration data and secrets to an nginx Deployment using Kubernetes ConfigMaps and Secrets instead of hardcoding values into the container. This approach keeps applications flexible and credentials protected.

- **ConfigMaps** store non-sensitive settings. (messages, log level, feature flags)
- **Secrets** for storing sensitive data. (Passwords, API Keys, Certificates)
- **Both** can be injected into Pods as environmental variables (or files) without rebuilding images

[**Click here to return to the Demos**](../README.md#demos)