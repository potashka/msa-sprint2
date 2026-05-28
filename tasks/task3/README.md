## Подготовка окружения

В task3 реализован федеративный GraphQL API для личного кабинета Hotelio:

- `booking-subgraph` — бронирования пользователя и ACL по header `userid`;
- `hotel-subgraph` — данные отелей и federation entity `Hotel`;
- `apollo-gateway` — единая GraphQL-точка входа на порту `4000`.

Запуск:

```bash
cd tasks/task3
docker compose up -d --build
```

`hotel-subgraph` умеет обращаться к REST API монолита через переменную `MONOLITH_URL`. Если переменная не задана или монолит недоступен, используется fallback mock data.

Пример запуска с монолитом, опубликованным на host port `8084`:

```bash
MONOLITH_URL=http://host.docker.internal:8084 docker compose up -d --build
```

Без `MONOLITH_URL` task3 запускается автономно.

---

## Проверка корректности

GraphQL endpoint gateway:

```text
http://localhost:4000/
```

### Успешный запрос

Headers:

```json
{
  "userid": "user1"
}
```

Query:

```graphql
query {
  bookingsByUser(userId: "user1") {
    id
    userId
    hotelId
    hotel {
      id
      name
      city
    }
    discountPercent
    promoCode
  }
}
```

curl:

```bash
curl -s http://localhost:4000/ \
  -H "content-type: application/json" \
  -H "userid: user1" \
  --data '{"query":"query { bookingsByUser(userId: \"user1\") { id userId hotelId hotel { id name city } discountPercent promoCode } }"}'
```

### Запрет доступа

Если header `userid` не совпадает с аргументом `userId`, пользователь не получает чужие бронирования.

Headers:

```json
{
  "userid": "user2"
}
```

Query:

```graphql
query {
  bookingsByUser(userId: "user1") {
    id
    userId
  }
}
```

Ожидаемый результат: пустой список `bookingsByUser`.

```bash
curl -s http://localhost:4000/ \
  -H "content-type: application/json" \
  -H "userid: user2" \
  --data '{"query":"query { bookingsByUser(userId: \"user1\") { id userId } }"}'
```

### Запрос без header

Без header `userid` пользователь считается неавторизованным.

```bash
curl -s http://localhost:4000/ \
  -H "content-type: application/json" \
  --data '{"query":"query { bookingsByUser(userId: \"user1\") { id userId } }"}'
```

Ожидаемый результат: пустой список `bookingsByUser`.

---

## Команды логов

```bash
cd tasks/task3
docker compose logs -f apollo-gateway
docker compose logs -f booking-subgraph
docker compose logs -f hotel-subgraph
```

В логах `booking-subgraph` видно, какой `userid` пришел в header и какой результат дала ACL-проверка.
