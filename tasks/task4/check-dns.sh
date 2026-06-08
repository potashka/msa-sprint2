#!/bin/bash
set -e

POD_NAME="booking-service-dns-test-$(date +%s)"

cleanup() {
  kubectl delete pod "${POD_NAME}" --ignore-not-found=true >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Running in-cluster DNS test..."
echo "Creating temporary pod ${POD_NAME}..."
kubectl run "${POD_NAME}" \
  --restart=Never \
  --image=busybox:1.36 \
  --command -- sleep 300 >/dev/null

kubectl wait --for=condition=Ready "pod/${POD_NAME}" --timeout=60s >/dev/null

echo "Requesting http://booking-service/ping from ${POD_NAME}..."
kubectl exec "${POD_NAME}" -- wget -qO- http://booking-service/ping

echo
echo "Success: booking-service is reachable via Kubernetes DNS"
