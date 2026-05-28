# Отчет по task3

## Изменения в booking-subgraph

- Добавлен Query `bookingsByUser(userId: String!): [Booking!]!`.
- Описан тип `Booking` с полями `id`, `userId`, `hotelId`, `promoCode`, `discountPercent`, `hotel`.
- Добавлена federation-связь с `Hotel` через `type Hotel @key(fields: "id")`.
- Resolver `Booking.hotel` возвращает reference `{ __typename: "Hotel", id: booking.hotelId }`.
- Реализован простой ACL по HTTP header `userid`.
- В логах фиксируются `requestedUser`, `headerUser` и результат ACL: `ALLOW` или `DENY`.

## Изменения в hotel-subgraph

- Добавлен тип `Hotel @key(fields: "id")` с полями `id`, `name`, `city`, `rating`, `stars`.
- Реализован resolver `Hotel.__resolveReference`, который получает `Hotel` по `id`.
- Добавлен Query `hotelsByIds(ids: [ID!]!): [Hotel]`.
- Добавлен слой функций `fetchHotel` и `fetchHotels`: сначала пробуется REST-вызов к монолиту через `MONOLITH_URL`, при недоступности используется mock data.

## Изменения в gateway

- Apollo Gateway агрегирует два subgraph:
  - `booking-subgraph` на `http://booking-subgraph:4001`;
  - `hotel-subgraph` на `http://hotel-subgraph:4002`.
- Gateway слушает порт `4000`.
- Header `userid` пробрасывается в subgraphs через `RemoteGraphQLDataSource`.

## Как работает Apollo Federation

`booking-subgraph` отвечает за бронирования, а `hotel-subgraph` отвечает за данные отелей. Gateway строит federated schema из subgraph schemas и принимает клиентский GraphQL-запрос на единой точке входа.

Когда клиент запрашивает:

```graphql
booking {
  hotel {
    name
    city
  }
}
```

Gateway сначала получает бронирования из `booking-subgraph`, затем по federation reference обращается в `hotel-subgraph`, чтобы дорезолвить поля `Hotel`.

## Как работает связь Booking.hotel

В `booking-subgraph` поле `Booking.hotel` не хранит весь отель. Resolver возвращает ссылку:

```js
{ __typename: 'Hotel', id: booking.hotelId }
```

`hotel-subgraph` реализует `Hotel.__resolveReference({ id })` и по этому `id` возвращает полные данные отеля. Это стандартный federation-паттерн для связи сущностей между subgraphs.

## Как работает ACL по header userid

`booking-subgraph` читает `req.headers.userid`.

- Если header отсутствует, возвращается пустой список.
- Если `userid` из header не равен аргументу `userId`, возвращается пустой список.
- Если `userid` совпадает с аргументом `userId`, возвращаются бронирования пользователя.

Таким образом пользователь может видеть только свои бронирования.

## Как запустить task3

```bash
cd tasks/task3
docker compose up -d --build
```

Gateway доступен на:

```text
http://localhost:4000/
```

Для автоматических проверок не используется GET `http://localhost:4000/`, потому что Apollo Sandbox UI может требовать интернет/CDN. Проверка выполняется только GraphQL POST-запросами.

## Успешный GraphQL-запрос

Файл запроса:

```text
tasks/task3/results/graphql-success-request.graphql
```

Header:

```text
userid: user1
```

curl:

```bash
curl -s http://localhost:4000/graphql \
  -H "content-type: application/json" \
  -H "userid: user1" \
  --data '{"query":"query { bookingsByUser(userId: \"user1\") { id userId hotelId hotel { id name city } discountPercent promoCode } }"}'
```

Если `/graphql` недоступен, можно выполнить тот же POST на fallback endpoint:

```bash
curl -s http://localhost:4000/ \
  -H "content-type: application/json" \
  -H "userid: user1" \
  --data '{"query":"query { bookingsByUser(userId: \"user1\") { id userId hotelId hotel { id name city } discountPercent promoCode } }"}'
```

## Deny-запрос по ACL

Файл запроса:

```text
tasks/task3/results/graphql-deny-request.graphql
```

Header:

```text
userid: user2
```

Аргумент запроса остается `userId: "user1"`, поэтому ACL должен вернуть пустой список.

```bash
curl -s http://localhost:4000/graphql \
  -H "content-type: application/json" \
  -H "userid: user2" \
  --data '{"query":"query { bookingsByUser(userId: \"user1\") { id userId hotelId hotel { id name city } discountPercent promoCode } }"}'
```

## Как собрать логи и результаты

После запуска `docker compose up -d --build` из корня репозитория выполнить:

```bash
bash tasks/task3/collect-results.sh
```

Скрипт:

- сохраняет `docker ps`;
- выполняет успешный GraphQL POST-запрос;
- выполняет Deny GraphQL POST-запрос;
- сохраняет логи `booking-subgraph`;
- сохраняет общие `docker compose logs`.

## Файлы-доказательства в results

- `docker-ps.txt` — состояние контейнеров.
- `graphql-success-request.graphql` — успешный запрос.
- `graphql-success-response.json` — ответ успешного запроса.
- `graphql-deny-request.graphql` — запрос для проверки ACL Deny.
- `graphql-deny-response.json` — ответ Deny-запроса.
- `booking-subgraph-logs.txt` — логи ACL из `booking-subgraph`.
- `docker-compose-logs.txt` — общие логи всех сервисов task3.
- `screenshot-success.png` — ручной скриншот успешного запроса, если Apollo Sandbox доступен.
- `screenshot-deny-acl.png` — ручной скриншот Deny-сценария, если Apollo Sandbox доступен.
