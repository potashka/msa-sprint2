#!/bin/bash
set -e

REQUESTS="${REQUESTS:-100}"
CLIENT_POD="$(kubectl get pod -l app=booking-service,version=v1 -o jsonpath='{.items[0].metadata.name}')"

if [ -z "${CLIENT_POD}" ]; then
  echo "No v1 booking-service pod found. Deploy v1 before running this check."
  exit 1
fi

echo "Checking canary split with ${REQUESTS} requests from pod ${CLIENT_POD}..."
RESPONSES="$(kubectl exec "${CLIENT_POD}" -c booking-service -- sh -c "for i in \$(seq 1 ${REQUESTS}); do wget -qO- http://booking-service/ping; echo; done")"

V1_COUNT="$(printf "%s\n" "${RESPONSES}" | grep -c "pong from v1" || true)"
V2_COUNT="$(printf "%s\n" "${RESPONSES}" | grep -c "pong from v2" || true)"

echo "v1 responses: ${V1_COUNT}"
echo "v2 responses: ${V2_COUNT}"
echo
echo "Expected approximate split: v1 around 90%, v2 around 10%."
echo "Raw responses:"
printf "%s\n" "${RESPONSES}"

if [ "${V1_COUNT}" -eq 0 ] || [ "${V2_COUNT}" -eq 0 ]; then
  echo "Canary check did not observe both versions. Retry the check or inspect Istio config."
  exit 1
fi
