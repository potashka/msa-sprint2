#!/bin/bash
set -e

echo "Checking booking-service pods..."
kubectl get pods -l app=booking-service || true

echo
echo "Checking booking-service service..."
kubectl get svc booking-service || true

echo
echo "Helm releases..."
helm list || true

echo
echo "Manual checks:"
echo "  kubectl port-forward svc/booking-service 18080:80"
echo "  curl http://localhost:18080/ping"
echo "  curl http://localhost:18080/ready"
echo "  curl http://localhost:18080/feature"
echo "  ./check-dns.sh"

echo
echo "Quick local curl if port-forward is already running:"
if curl --fail --max-time 2 http://localhost:18080/ping; then
  echo
  echo "Reachable through local port-forward"
else
  echo "Port-forward is not running or service is not reachable on localhost:18080"
fi
