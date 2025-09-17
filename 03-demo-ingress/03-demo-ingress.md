# Demo 3 - Ingress with Traefik

This demo will show how to expose a deployment using an Ingress resource. Instead of relying on port forwarding or NodePort, we can use an ingress controller to make an app accessible at a real hostname. This is the recommended way to expose HTTP/HTTPS traffic into Kubernetes.

## Learning Goals

- Understand the difference between a Service and an Ingress
- Learn how an ingress controller handles external traffic
- Configure a hostname to access an app in a browser

## Prerequisites

- **Complete** [**Initial Setup Guide**](../00-initial-setup/initial-setup.md)
- Access to the terminal of the control node. I recommend using SSH.

## 1 - Nginx Manifest with Ingress Controller

The first thing we need is a Manifest. We'll add to our simple deployment example from our previous demos.

- The Service only provides networking inside the cluster
- The Ingress section allows external access to the cluster at `http://nginx.local`

Conveniently, K3s includes Traefik as a built-in Ingress Controller. We will be using this for our demo:

```yaml
# Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
---
# Service
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
---
# New Ingress Section
apiVersion: networking.k8s.io/v1
kind: Ingress           # Specifies type
metadata:
  name: nginx-ingress
  annotations:          # Tell traefik to use port 80 as an entrypoint
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
    - host: nginx.local       # Hostname to use
      http:
        paths:
          - path: /           # Route all requests to nginx service
            pathType: Prefix
            backend:          # Define the service to route to
              service:
                name: nginx
                port:
                  number: 80

```

### 2. Deploy the Manifest file

#### 1. Apply the Manifest to the Cluster

```bash
sudo kubectl apply -f https://raw.githubusercontent.com/kcskier/k3s-cluster-demo/main/manifests/demo/30-ingress_example.yaml

```

#### 2. Edit the hosts file on Control Node. (`rd-rp51` in my case) Open `/etc/hosts`:

```bash
sudo nano /etc/hosts
```

And add the following line:
```bash
127.0.0.1 nginx.local
```

> *Note: This only is done on the control node*

## 3. Test with Curl

On your control node, run the following:

```bash
curl http://nginx.local
```

You should now see the default nginx welcome page in your terminal:

```bash
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

**Congratulations!** You just set up an Ingress Controller!

## 4. Cleanup

#### 1. Delete the Ingress
```bash
sudo kubectl delete ingress nginx-ingress
```

#### 2. Delete the Service
```bash
sudo kubectl delete service nginx
```

#### 3. Delete the Deployment
```bash
sudo kubectl delete deployment nginx
```

#### 4. Verify that all was deleted from cluster
```bash
sudo kubectl get pods &&
sudo kubectl get ingress &&
sudo kubectl get deployment &&
sudo kubectl get service
```

Example Output:
```bash
# Example pods, ingress and deployment output
No resources found in default namespace.

# Service output should show only the default cluster service
```

#### 5. Remove line from `/etc/hosts`
Remove the line you added to the `/etc/hosts` file

```bash
sudo nano /etc/hosts
```

Example Output:
```bash
# Remove this line
127.0.0.1   nginx.local
```

## Conclusion

In this demo, you exposed the nginx app through an Ingress using K3s's built-in Traefik controller instead of using port-forwarding or NodePorts. Just like a production environment, we were able to access nginx via a hostname.

- **Services** provide stable networking inside the cluster.
- **Ingress** provides controlled access from outside the cluster.
- **Ingress controllers** (like Traefik) make advanced routing, TLS, and multiple hostnames possible.
- **The traffic flow built in this demo**: curl → Ingress (Traefik) → Service → Pods

[**Click here to return to the Demos**](../README.md#demos)