# Locust KEDA Workshop Example

This directory contains a CPU-based autoscaling example using **KEDA** with a simple FastAPI web app stressed by **Locust** (headless mode only).

## 📋 Overview

In this workshop, we demonstrate **KEDA autoscaling based on CPU utilization** using a simple Python web application and Locust for load generation.

- **The Web App**: A FastAPI application that exposes a `/fib?n=35` endpoint. This endpoint intentionally performs a CPU-intensive Fibonacci calculation to simulate heavy processing load per request.
- **Load Generation with Locust**: We use Locust in headless mode to simulate multiple users continuously hitting the `/fib` endpoint. This gradually drives CPU utilization of the `webapp` pods very high.
- **Autoscaling with KEDA**: 
  - KEDA watches the CPU metrics of the `webapp` Deployment.
  - When CPU usage exceeds **60%**, the Horizontal Pod Autoscaler (HPA) created by KEDA starts scaling the deployment.
  - The app will scale from **1 pod** up to a maximum of **10 pods** as defined in the ScaledObject.
  - Once the Locust job is deleted and the load disappears, KEDA will signal the HPA to scale the deployment back down.

⚠️ **Important Difference from Redis/Kafka examples**  
Unlike event-driven scalers (like Redis queue length or Kafka lag), the **CPU scaler cannot scale to zero**. This is because CPU metrics are only available when at least one pod is running.  
- Minimum replicas (`minReplicaCount`) will always stay at **1**.  
- So after the Locust job ends, the deployment scales down from 10 → … → 1, but **never to 0**.

This exercise highlights:
- How to generate real CPU load with Locust.
- How KEDA integrates with the Kubernetes Metrics Server to autoscale based on CPU.
- The difference between **metric-driven scaling (CPU, memory)** vs. **event-driven scaling (queues, streams)**.

## 🚀 Quick Start

1. **Deploy the app and scaler:**
   ```bash
   kubectl apply -f locust-deployment.yaml -n workshop-user-x
   kubectl apply -f locust-service.yaml -n workshop-user-x
   kubectl apply -f locust-scaledobject.yaml -n workshop-user-x
   ```

2. **Observe autoscaling:**
   Run this in parallel in multiple terminals
   ```bash
   kubectl get pods -n workshop-user-x -l app=webapp -w
   watch -n2 'kubectl top pods -n workshop-user-x --no-headers | sort -k2 -hr'
   kubectl get hpa -n workshop-user-x -w
   ```

3. **Run Locust load test (headless mode):**
   In a new terminal:
   ```bash
   kubectl apply -f locust-job.yaml -n workshop-user-x
   POD=$(kubectl get pod -l job-name=locust-headless -o jsonpath='{.items[0].metadata.name}' -n workshop-user-x)
   kubectl logs -f $POD -n workshop-user-x
   ```

4. **Delete Locust load test job (headless mode):**
   After scaling up to several webapps you can delete the locust job, and wait for scale down to 1:
   ```bash
   kubectl delete job locust-headless -n workshop-user-x --ignore-not-found
   ```  

5. **Debugg:**
   If some pods still "hang" you can check the namespace events:
   ```bash
   kubectl get events -n workshop-user-2 --sort-by=.lastTimestamp | tail -n 50
   ```   
   

## 🏗️ Architecture

```
[ Locust Job ] ---> [ Service webapp ] ---> [ FastAPI /fib endpoint ]
                                    |
                                 [ KEDA CPU scaler ]
                                    |
                                [ more replicas ]
```

## ⚙️ Configuration Details

**Web App**
- Image: `tiangolo/uvicorn-gunicorn-fastapi:python3.11`
- Endpoint: `GET /fib?n=35` (adjust `n` to make it easier/harder)

**KEDA**
- Trigger: CPU utilization (`60%`)
- Min: 1 pod, Max: 10 pods
- Cooldown: 60s
- Polling interval: 5s

**Locust**
- Image: `locustio/locust:2.32.2`
- Headless Job: 150 users, 15 ramp-up users/s, run for 5 minutes


## 🧩 Files & Explanations

### `webapp-deployment.yaml` — App code + Deployment
- **ConfigMap**: holds `main.py` so we don’t need a custom image.  
- **FastAPI**: minimal web framework; perfect for a CPU demo.  
- **Fibonacci**: naive recursion to simulate CPU stress.  
- **Requests/Limits**: needed so HPA/KEDA can compute CPU utilization.

### `webapp-service.yaml` — Stable access + load balancing
- **Service**: exposes the webapp pods via stable DNS (`webapp`).  
- **Port 80**: matches the container’s default HTTP port.

### `keda-scaledobject.yaml` — CPU-based autoscaling
- **scaleTargetRef**: Deployment `webapp`.  
- **minReplicaCount/maxReplicaCount**: bounds for scaling.  
- **pollingInterval/cooldownPeriod**: control evaluation + scale-down.  
- **trigger**: CPU utilization target (e.g., 60%).  
- KEDA runs in `keda-system` but manages HPA inside your namespace.

### `locust-job.yaml` — Load generator (headless)
- **Locust** simulates many users hitting `/fib?n=35`.  
- **ConfigMap** with `locustfile.py`: defines the load test.  
- **Job** ensures Locust runs once, then exits (or after `--run-time`).  
- **Flags**:  
  - `--headless`: no UI.  
  - `-u`: users.  
  - `-r`: spawn rate.  
  - `--run-time`: test duration.  
- **Namespace injection**: `NAMESPACE` env var ensures the Job targets the correct Service DNS.


## 🧹 Cleanup

```bash
kubectl delete -f locust-job.yaml || true
kubectl delete -f locust-scaledobject.yaml
kubectl delete -f locust-deployment.yaml
kubectl delete -f locust-service.yaml
```
