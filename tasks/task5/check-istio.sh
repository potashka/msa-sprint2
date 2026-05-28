#!/bin/bash
set -e

echo "Checking Istio control plane..."
kubectl get pods -n istio-system

echo
echo "Checking default namespace sidecar injection label..."
INJECTION="$(kubectl get namespace default -o jsonpath='{.metadata.labels.istio-injection}')"
echo "istio-injection=${INJECTION:-<empty>}"
if [ "${INJECTION}" != "enabled" ]; then
  echo "Expected istio-injection=enabled"
  echo "Run: kubectl label namespace default istio-injection=enabled --overwrite"
  exit 1
fi

echo
echo "Checking booking-service Istio resources..."
kubectl get virtualservice booking-service
kubectl get destinationrule booking-service

echo
echo "Istio check passed"
