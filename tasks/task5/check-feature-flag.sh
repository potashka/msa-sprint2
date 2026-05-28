#!/bin/bash
set -e

REQUESTS="${REQUESTS:-10}"
CLIENT_POD="$(kubectl get pod -l app=booking-service,version=v1 -o jsonpath='{.items[0].metadata.name}')"

if [ -z "${CLIENT_POD}" ]; then
  echo "No v1 booking-service pod found. Deploy v1 before running this check."
  exit 1
fi

echo "Checking feature flag routing with header X-Feature-Enabled: true from pod ${CLIENT_POD}..."
RESPONSES="$(kubectl exec "${CLIENT_POD}" -c booking-service -- sh -c "for i in \$(seq 1 ${REQUESTS}); do wget -qO- --header='X-Feature-Enabled: true' http://booking-service/ping; echo; done")"

V2_COUNT="$(printf "%s\n" "${RESPONSES}" | grep -c "pong from v2" || true)"

echo "v2 responses with feature header: ${V2_COUNT}/${REQUESTS}"
echo "Raw responses:"
printf "%s\n" "${RESPONSES}"

if [ "${V2_COUNT}" -ne "${REQUESTS}" ]; then
  echo "Feature flag routing failed: expected all responses from v2."
  exit 1
fi

echo "Feature flag routing passed"
