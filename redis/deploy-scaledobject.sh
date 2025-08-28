#!/bin/bash

# =====================================================
# KEDA Redis ScaledObject Deployment Script
# =====================================================
# 
# This script deploys the Redis KEDA ScaledObject with the correct
# namespace-specific Redis address. This is required because:
# 
# 1. KEDA operator runs in keda-system namespace
# 2. Redis service runs in your workshop namespace 
# 3. KEDA needs full DNS name to reach Redis across namespaces
#
# Usage: 
#   ./deploy-scaledobject.sh                              # Auto-detect namespace
#   NAMESPACE=workshop-user-X ./deploy-scaledobject.sh    # Specify namespace
#   kubectl config set-context --current --namespace=workshop-user-X && ./deploy-scaledobject.sh
# =====================================================

# Get current namespace - try multiple methods
# First check if NAMESPACE is provided as environment variable
if [ -z "$NAMESPACE" ]; then
    NAMESPACE=$(kubectl config view --minify -o jsonpath='{.contexts[0].context.namespace}')
fi

# If no namespace in context, try to get the current namespace from kubectl
if [ -z "$NAMESPACE" ]; then
    NAMESPACE=$(kubectl config get-contexts --no-headers | grep '^\*' | awk '{print $5}')
fi

# If still no namespace, try to detect workshop namespace or use default
if [ -z "$NAMESPACE" ] || [ "$NAMESPACE" = "default" ]; then
    # Look for workshop-user-* namespaces and prompt user
    WORKSHOP_NAMESPACES=$(kubectl get namespaces -o name | grep "workshop-user" | head -5)
    if [ ! -z "$WORKSHOP_NAMESPACES" ]; then
        echo "🔍 Available workshop namespaces:"
        kubectl get namespaces | grep "workshop-user"
        echo ""
        echo "Please specify your namespace:"
        echo "Usage: NAMESPACE=workshop-user-X ./deploy-scaledobject.sh"
        echo "   or: kubectl config set-context --current --namespace=workshop-user-X"
        exit 1
    else
        echo "⚠️  No namespace configured, using 'default'"
        NAMESPACE="default"
    fi
fi

echo "🚀 Deploying KEDA ScaledObject for namespace: $NAMESPACE"

# Replace NAMESPACE placeholder in the ScaledObject
sed "s/NAMESPACE/$NAMESPACE/g" redis-scaledobject.yaml | kubectl apply -f -

if [ $? -eq 0 ]; then
    echo "✅ ScaledObject deployed successfully"
    echo "📊 Check status with: kubectl get scaledobjects"
    echo "📈 Monitor scaling with: kubectl get hpa"
else
    echo "❌ Failed to deploy ScaledObject"
    exit 1
fi