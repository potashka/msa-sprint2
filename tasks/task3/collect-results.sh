#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"

GATEWAY_GRAPHQL_URL="${GATEWAY_GRAPHQL_URL:-http://localhost:4000/graphql}"
GATEWAY_FALLBACK_URL="${GATEWAY_FALLBACK_URL:-http://localhost:4000/}"

mkdir -p "${RESULTS_DIR}"

post_graphql() {
  local header_userid="$1"
  local output_file="$2"
  local payload='{"query":"query { bookingsByUser(userId: \"user1\") { id userId hotelId hotel { id name city } discountPercent promoCode } }"}'

  echo "POST ${GATEWAY_GRAPHQL_URL} -> ${output_file}"
  if [ -n "${header_userid}" ]; then
    if curl -fsS "${GATEWAY_GRAPHQL_URL}" \
      -H "content-type: application/json" \
      -H "userid: ${header_userid}" \
      --data "${payload}" > "${output_file}"; then
      return 0
    fi

    echo "Основной endpoint /graphql не ответил, пробую fallback ${GATEWAY_FALLBACK_URL}"
    curl -fsS "${GATEWAY_FALLBACK_URL}" \
      -H "content-type: application/json" \
      -H "userid: ${header_userid}" \
      --data "${payload}" > "${output_file}"
  else
    if curl -fsS "${GATEWAY_GRAPHQL_URL}" \
      -H "content-type: application/json" \
      --data "${payload}" > "${output_file}"; then
      return 0
    fi

    echo "Основной endpoint /graphql не ответил, пробую fallback ${GATEWAY_FALLBACK_URL}"
    curl -fsS "${GATEWAY_FALLBACK_URL}" \
      -H "content-type: application/json" \
      --data "${payload}" > "${output_file}"
  fi
}

echo "== Task3: фиксация результатов Apollo Federation =="
echo "Папка результатов: ${RESULTS_DIR}"

echo "1/5 Сохраняю docker ps..."
docker ps > "${RESULTS_DIR}/docker-ps.txt"

echo "2/5 Выполняю успешный GraphQL POST-запрос с userid: user1..."
post_graphql "user1" "${RESULTS_DIR}/graphql-success-response.json"

echo "3/5 Выполняю Deny GraphQL POST-запрос с userid: user2..."
post_graphql "user2" "${RESULTS_DIR}/graphql-deny-response.json"

echo "4/5 Сохраняю логи booking-subgraph..."
(
  cd "${SCRIPT_DIR}"
  docker compose logs booking-subgraph
) > "${RESULTS_DIR}/booking-subgraph-logs.txt"

echo "5/5 Сохраняю общие docker compose logs..."
(
  cd "${SCRIPT_DIR}"
  docker compose logs
) > "${RESULTS_DIR}/docker-compose-logs.txt"

echo "Готово. Файлы сохранены в ${RESULTS_DIR}."
echo "Скриншоты Apollo Sandbox нужно сделать вручную, если UI доступен:"
echo "  ${RESULTS_DIR}/screenshot-success.png"
echo "  ${RESULTS_DIR}/screenshot-deny-acl.png"
echo "Если Sandbox не загружается без интернета/CDN, достаточно JSON-ответов curl из results."
