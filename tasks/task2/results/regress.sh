#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${API_URL:-http://localhost:8084}"
FIXTURES_FILE="${FIXTURES_FILE:-${SCRIPT_DIR}/../../../test/init-fixtures.sql}"

pass() { echo "OK: $1"; }
fail() { echo "FAIL: $1"; exit 1; }

wait_http() {
  for i in {1..60}; do
    if curl -fsS "${BASE}/api/bookings" >/dev/null 2>&1; then
      return 0
    fi
    echo "Waiting for monolith HTTP API (${i}/60)..."
    sleep 2
  done
  fail "monolith API is not ready"
}

wait_history_event() {
  local booking_id="$1"
  for i in {1..30}; do
    if docker exec hotelio-history-db psql -U history -d history -tAc \
      "SELECT count(*) FROM booking_history WHERE booking_id='${booking_id}'" | grep -q '^1$'; then
      return 0
    fi
    echo "Waiting for booking history event (${i}/30)..."
    sleep 2
  done
  fail "booking history event was not consumed"
}

echo "Task2 regression: gRPC booking-service + Kafka history"
wait_http

echo "Loading monolith fixtures..."
docker exec -i hotelio-db psql -U hotelio -d hotelio < "${FIXTURES_FILE}"

echo "Checking existing monolith APIs..."
curl -fsS "${BASE}/api/users/test-user-1" | grep -q 'Alice' && pass "user lookup" || fail "user lookup"
curl -fsS "${BASE}/api/users/test-user-3/vip" | grep -q 'true' && pass "VIP status" || fail "VIP status"
curl -fsS "${BASE}/api/hotels/test-hotel-1/operational" | grep -q 'true' && pass "hotel operational" || fail "hotel operational"
curl -fsS "${BASE}/api/hotels/test-hotel-2/fully-booked" | grep -q 'true' && pass "hotel fully-booked" || fail "hotel fully-booked"
curl -fsS "${BASE}/api/reviews/hotel/test-hotel-1/trusted" | grep -q 'true' && pass "trusted hotel" || fail "trusted hotel"
curl -fsS "${BASE}/api/promos/TESTCODE1" | grep -q 'TESTCODE1' && pass "promo lookup" || fail "promo lookup"
curl -fsS -X POST "${BASE}/api/promos/validate?code=TESTCODE1&userId=test-user-2" | grep -q 'TESTCODE1' \
  && pass "promo validate" || fail "promo validate"

echo "Checking monolith GET /api/bookings remains available..."
curl -fsS "${BASE}/api/bookings" | grep -q 'test-user-2' && pass "monolith booking list" || fail "monolith booking list"

echo "Creating booking through monolith -> gRPC booking-service..."
CREATE_RESPONSE="$(curl -fsS -X POST "${BASE}/api/bookings?userId=test-user-2&hotelId=test-hotel-1&promoCode=TESTCODE1")"
echo "${CREATE_RESPONSE}" | grep -q 'TESTCODE1' && pass "booking created with promo" || fail "booking create with promo"

BOOKING_ID="$(echo "${CREATE_RESPONSE}" | sed -n 's/.*"id":\([0-9][0-9]*\).*/\1/p')"
if [[ -z "${BOOKING_ID}" ]]; then
  fail "booking id was not returned"
fi

docker exec hotelio-booking-db psql -U booking -d booking -tAc \
  "SELECT count(*) FROM bookings WHERE id=${BOOKING_ID} AND user_id='test-user-2' AND hotel_id='test-hotel-1'" | grep -q '^1$' \
  && pass "booking stored in booking-db" || fail "booking was not stored in booking-db"

wait_history_event "${BOOKING_ID}"
pass "BookingCreated consumed into booking_history"

echo "Checking rejection cases still fail through the new path..."
code="$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE}/api/bookings?userId=test-user-0&hotelId=test-hotel-1")"
[[ "${code}" == "500" ]] && pass "inactive user rejected" || fail "inactive user returned ${code}"

code="$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE}/api/bookings?userId=test-user-2&hotelId=test-hotel-2")"
[[ "${code}" == "500" ]] && pass "fully booked hotel rejected" || fail "fully booked hotel returned ${code}"

echo "All task2 regression checks passed."
