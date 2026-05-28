#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
BASE_URL="${API_URL:-http://localhost:8084}"

mkdir -p "${RESULTS_DIR}"

echo "== Task2: фиксация результатов =="
echo "Папка результатов: ${RESULTS_DIR}"

echo "1/7 Запускаю regress.sh и сохраняю test-log.txt..."
bash "${RESULTS_DIR}/regress.sh" > "${RESULTS_DIR}/test-log.txt" 2>&1
echo "  -> ${RESULTS_DIR}/test-log.txt"

echo "2/7 Сохраняю docker ps..."
docker ps > "${RESULTS_DIR}/docker-ps.txt"
echo "  -> ${RESULTS_DIR}/docker-ps.txt"

echo "3/7 Сохраняю листинг бронирований через REST монолита..."
curl -fsS "${BASE_URL}/api/bookings" > "${RESULTS_DIR}/bookings-rest-monolith.txt"
echo "  -> ${RESULTS_DIR}/bookings-rest-monolith.txt"

echo "4/7 Сохраняю листинг бронирований напрямую через gRPC booking-service..."
docker exec -e BOOKING_GRPC_TARGET=localhost:9090 hotelio-booking-service \
  node src/list-bookings.js > "${RESULTS_DIR}/bookings-grpc-service.txt"
echo "  -> ${RESULTS_DIR}/bookings-grpc-service.txt"

echo "5/7 Сохраняю select из старой БД монолита..."
{
  echo "-- Monolith DB: legacy table is named booking"
  echo "-- SQL: SELECT * FROM booking ORDER BY id;"
  docker exec hotelio-db psql -U hotelio -d hotelio -c "SELECT * FROM booking ORDER BY id;"
} > "${RESULTS_DIR}/bookings-old-db.txt"
echo "  -> ${RESULTS_DIR}/bookings-old-db.txt"

echo "6/7 Сохраняю select из новой БД booking-service..."
{
  echo "-- Booking-service DB"
  echo "-- SQL: SELECT * FROM bookings ORDER BY id;"
  docker exec hotelio-booking-db psql -U booking -d booking -c "SELECT * FROM bookings ORDER BY id;"
} > "${RESULTS_DIR}/bookings-new-db.txt"
echo "  -> ${RESULTS_DIR}/bookings-new-db.txt"

echo "7/7 Сохраняю select из БД booking-history-service..."
{
  echo "-- Booking-history-service DB"
  echo "-- SQL: SELECT * FROM booking_history ORDER BY id;"
  docker exec hotelio-history-db psql -U history -d history -c "SELECT * FROM booking_history ORDER BY id;"
} > "${RESULTS_DIR}/booking-history.txt"
echo "  -> ${RESULTS_DIR}/booking-history.txt"

echo "Готово. Результаты сохранены в ${RESULTS_DIR}."
