#!/bin/bash
set -e

echo "Fallback / retry demonstration"
echo
echo "Istio retries and circuit breaking are configured in destination-rule.yaml and virtual-service.yaml."
echo "Automatic fallback from subset v1 to subset v2 is not guaranteed by this config when v1 is scaled to zero;"
echo "the canary route still contains explicit subset weights. This script provides a safe manual check."
echo
echo "Manual fallback experiment:"
echo "  kubectl scale deployment booking-service-v1 --replicas=0"
echo "  REQUESTS=20 ./check-canary.sh"
echo "  kubectl scale deployment booking-service-v1 --replicas=1"
echo

if [ "${RUN_FALLBACK_TEST:-false}" != "true" ]; then
  echo "Set RUN_FALLBACK_TEST=true to execute the scale-down experiment automatically."
  exit 0
fi

echo "Scaling v1 to zero..."
kubectl scale deployment booking-service-v1 --replicas=0
kubectl rollout status deployment/booking-service-v1 --timeout=60s || true

echo "Sending requests while v1 is scaled down..."
CLIENT_POD="$(kubectl get pod -l app=booking-service,version=v2 -o jsonpath='{.items[0].metadata.name}')"
RESPONSES="$(kubectl exec "${CLIENT_POD}" -c booking-service -- sh -c "for i in \$(seq 1 20); do wget -qO- http://booking-service/ping || true; echo; done")"
printf "%s\n" "${RESPONSES}"

echo "Restoring v1..."
kubectl scale deployment booking-service-v1 --replicas=1
kubectl rollout status deployment/booking-service-v1 --timeout=120s
