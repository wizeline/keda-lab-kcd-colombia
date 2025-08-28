# Wizeline KEDA Workshop - Attendees guide

Welcome to the KEDA Workshop developed by Wizeline. Here you will learn the basic concepts of KEDA and also will be guided through some exercises that will help you to understand the KEDA components inside a Kubernetes cluster and interact with them.

## Cluster Architecture

You will receive a kubeconfig file which will grant you access to an isolated namespace inside our cluster. Add to your contexts list and step into it so you can start interacting with it.

You will have all the required permissions to create the neccesary resources inside your namespace and you will also be able to see other's resources but not able to modify them.

In case you get errors related with permissions please reach out to the Workshop organizers.


### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GKE Cluster                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐    │
│  │   keda-system   │ │  kube-system    │ │     default     │    │
│  │                 │ │                 │ │                 │    │
│  │ ┌─────────────┐ │ │ ┌─────────────┐ │ │ (unused)        │    │
│  │ │ KEDA        │ │ │ │ System      │ │ │                 │    │
│  │ │ Operator    │ │ │ │ Components  │ │ │                 │    │
│  │ │ + Metrics   │ │ │ │ (DNS, etc.) │ │ │                 │    │
│  │ └─────────────┘ │ │ └─────────────┘ │ │                 │    │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘    │
│                                                                  │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐    │
│  │workshop-user-1  │ │workshop-user-2  │ │workshop-user-N  │    │
│  │                 │ │                 │ │                 │    │
│  │ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │    │
│  │ │ResourceQuota│ │ │ │ResourceQuota│ │ │ │ResourceQuota│ │    │
│  │ │- CPU: 2/4   │ │ │ │- CPU: 2/4   │ │ │ │- CPU: 2/4   │ │    │
│  │ │- RAM: 4/8GB │ │ │ │- RAM: 4/8GB │ │ │ │- RAM: 4/8GB │ │    │
│  │ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │    │
│  │                 │ │                 │ │                 │    │
│  │ ┌─────────────┐ │ │ ┌─────────────┐ │ │ ┌─────────────┐ │    │
│  │ │ User Apps   │ │ │ │ User Apps   │ │ │ │ User Apps   │ │    │
│  │ │+ ScaledObjs │ │ │ │+ ScaledObjs │ │ │ │+ ScaledObjs │ │    │
│  │ └─────────────┘ │ │ └─────────────┘ │ │ └─────────────┘ │    │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

Before starting this exercise, ensure you have:

- A running Kubernetes cluster with `kubectl` access
- KEDA installed in your cluster
- Sufficient permissions to create deployments, services, and KEDA resources
- Basic familiarity with Kubernetes concepts

#### Step 1: Set Up Your Access

You will receive a file named `kubeconfig-user-X.yaml`. This gives you secure access to your dedicated Kubernetes namespace.

```bash
# Option A: Environment Variable (Recommended)
export KUBECONFIG=/path/to/kubeconfig-user-X.yaml
kubectl get pods

# Option B: Use --kubeconfig flag
kubectl --kubeconfig=/path/to/kubeconfig-user-X.yaml get pods

# Option C: Copy to default location
cp kubeconfig-user-X.yaml ~/.kube/config
kubectl get pods
```

#### Step 2: Verify Your Environment

```bash
# Check your current context and namespace
kubectl config current-context
kubectl config view --minify

# List resources in your namespace
kubectl get all

# View your resource limits
kubectl describe resourcequota

# Check available storage classes
kubectl get storageclass
```



