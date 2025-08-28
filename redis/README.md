# Redis Auto-Scaling with KEDA on Kubernetes

This guide provides a complete, hands-on exercise for implementing auto-scaling of Redis workers using KEDA (Kubernetes Event-Driven Autoscaling) in your Kubernetes namespace.

## Overview

KEDA allows you to scale your applications based on external metrics. In this exercise, we'll:
- Deploy a Redis instance to act as a message queue
- Create worker pods that process items from a Redis list
- Configure KEDA to automatically scale workers based on queue length
- Test the scaling behavior with a load generator

## Prerequisites

Before starting this exercise, ensure you have:

- A running Kubernetes cluster with `kubectl` access
- KEDA installed in your cluster
- Sufficient permissions to create deployments, services, and KEDA resources
- Basic familiarity with Kubernetes concepts

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Load Gen      │───▶│     Redis       │◀───│   Workers       │
│   (Job)         │    │   (Service)     │    │ (Deployment)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │                        │
                              │                        │
                       ┌─────────────────┐    ┌─────────────────┐
                       │   KEDA Scaler   │───▶│      HPA        │
                       │ (ScaledObject)  │    │  (Auto-created) │
                       └─────────────────┘    └─────────────────┘
```

## Quick Setup

All configuration files use `NAMESPACE` placeholder that needs to be replaced with your actual namespace:

Manually replace these placeholders:
- `redis.NAMESPACE.svc.cluster.local` → `redis.workshop-user-55.svc.cluster.local`


## Step-by-Step Implementation

### Step 1: Deploy Redis

Deploy Redis to serve as our message queue:

```bash
kubectl apply -f redis-deployment.yaml
kubectl apply -f redis-service.yaml

```

Verify Redis is running:
```bash
kubectl get pods -l app=redis
kubectl get service redis
```

Test Redis connectivity:
```bash
kubectl run redis-client --rm -it --image=redis:7-alpine -- redis-cli -a redis123 -h redis.workshop-user-55.svc.cluster.local -p 6379 ping

#In case you get an error in that terminal as this is a temporary pod. Run this on a separate terminal

kubectl logs redis-client 

# You should see this

PONG
```


### Step 2: Deploy Worker Application

Deploy the worker pods that will process items from the Redis queue:

```bash
# Replace NAMESPACE with your actual namespace, or use sed:
sed 's/NAMESPACE/workshop-user-55/g' task-processor.yaml | kubectl apply -f -
```

Verify workers are running:
```bash
kubectl get pods -l app=task-processor
kubectl logs -l app=task-processor
```

### Step 3: Configure KEDA Auto-Scaling

Apply the KEDA ScaledObject configuration:

```bash
# Use the automated script (recommended):
./deploy-scaledobject.sh

# Or replace NAMESPACE manually and apply:
sed 's/NAMESPACE/workshop-user-55/g' redis-scaledobject.yaml | kubectl apply -f -
```

Verify KEDA resources:
```bash
kubectl get scaledobjects
kubectl get hpa
```

### Step 4: Generate Load and Test Scaling

Generate load by deploying the task generator:

```bash
# Replace NAMESPACE with your actual namespace, or use sed:
sed 's/NAMESPACE/workshop-user-55/g' task-generator.yaml | kubectl apply -f -
```

Monitor the system:
```bash
# Watch the task generator creating tasks
kubectl logs -f -l app=task-generator

# Watch workers processing tasks (in another terminal)
kubectl logs -f -l app=task-processor

# Monitor scaling behavior (in another terminal)
watch 'kubectl get hpa; echo "---"; kubectl get pods -l app=task-processor'
```

### Step 5: Test Burst Scaling

To test rapid scaling, create a burst of tasks:

```bash
kubectl run redis-test --image=redis:7-alpine --restart=Never --command -- /bin/sh -c "
for i in \$(seq 1 20); do 
  redis-cli -h redis -a redis123 lpush task_queue '{\"id\":\"burst-\$i\",\"processing_time\":8,\"created_at\":\$(date +%s)}';
done; 
redis-cli -h redis -a redis123 llen task_queue"

# Check the result and clean up
kubectl logs redis-test
kubectl delete pod redis-test

# Watch the scaling response
kubectl get hpa
kubectl get pods -l app=task-processor
```

## Configuration Details

### KEDA ScaledObject Configuration

The key configuration in `redis-scaledobject.yaml`:

```yaml
triggers:
- type: redis
  metadata:
    address: redis.NAMESPACE.svc.cluster.local:6379
    listName: task_queue
    listLength: "5"          # Scale when queue has 5+ items
    activationListLength: "2" # Activate scaling when queue has 2+ items
```

### Scaling Behavior

- **Minimum Replicas**: 1 (always have at least one worker)
- **Maximum Replicas**: 10 (prevent resource exhaustion)
- **Polling Interval**: 15 seconds (how often KEDA checks the queue)
- **Cooldown Period**: 60 seconds (wait time before scaling down)
- **Trigger Threshold**: 5 items per worker (scale out when queue length / replicas > 5)

## Testing Scenarios

### Scenario 1: Basic Auto-Scaling

1. Start with 1 worker pod
2. Add 20 items to the queue rapidly
3. Observe workers scaling up to handle the load
4. Wait for queue to empty
5. Observe workers scaling back down

### Scenario 2: Sustained Load

1. Generate continuous load over 10 minutes
2. Observe steady-state scaling behavior
3. Monitor resource utilization

### Scenario 3: Burst Load

1. Generate 50 items quickly
2. Stop load generation
3. Observe rapid scale-up and gradual scale-down

## Monitoring Commands

### Check Queue Length
```bash
kubectl run redis-test --image=redis:7-alpine --restart=Never --command -- redis-cli -h redis -a redis123 llen task_queue
kubectl logs redis-test && kubectl delete pod redis-test
```

### Check Current Workers
```bash
kubectl get pods -l app=task-processor
```

### Check HPA Status
```bash
kubectl get hpa
kubectl describe hpa keda-hpa-redis-queue-scaler
```

### View KEDA Metrics
```bash
kubectl get scaledobjects redis-queue-scaler -o yaml
```

## Troubleshooting

### Common Issues

1. **KEDA not scaling**: Check if KEDA operator is running
   ```bash
   kubectl get pods -n keda
   ```

2. **Redis connection issues**: Verify service names and ports
   ```bash
   kubectl get svc redis
   ```

3. **Workers not processing**: Check worker logs
   ```bash
   kubectl logs -l app=task-processor
   ```

4. **Permission errors**: Verify RBAC configuration
   ```bash
   kubectl auth can-i create hpa --as=system:serviceaccount:default:keda-operator
   ```

### Debug Commands

```bash
# Check KEDA operator logs
kubectl logs -n keda -l app=keda-operator

# Describe the ScaledObject
kubectl describe scaledobject redis-queue-scaler

# Check HPA details
kubectl describe hpa keda-hpa-redis-queue-scaler

# View worker pod events
kubectl describe pods -l app=task-processor
```

## Cleanup

To remove all resources created in this workshop:

```bash
# Delete the applications
kubectl delete -f task-generator.yaml
kubectl delete -f task-processor.yaml

# Delete KEDA resources (replace NAMESPACE with your actual namespace)
sed 's/NAMESPACE/workshop-user-55/g' redis-scaledobject.yaml | kubectl delete -f -

# Delete Redis
kubectl delete -f redis-deployment.yaml
kubectl delete -f redis-service.yaml
```

Quick cleanup (replace all NAMESPACE placeholders first):
```bash
kubectl delete deployment task-generator task-processor redis
kubectl delete service redis
kubectl delete scaledobject redis-queue-scaler
kubectl delete secret redis-secret
kubectl delete triggerauthentication redis-auth
kubectl delete configmap redis-config task-generator-script task-processor-script
```

## Advanced Configuration

### Custom Scaling Policies

Modify the ScaledObject to include custom HPA behavior:

```yaml
spec:
  advanced:
    horizontalPodAutoscalerConfig:
      behavior:
        scaleUp:
          stabilizationWindowSeconds: 30
          policies:
          - type: Percent
            value: 100
            periodSeconds: 15
        scaleDown:
          stabilizationWindowSeconds: 300
          policies:
          - type: Percent
            value: 10
            periodSeconds: 60
```