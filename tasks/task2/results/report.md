# Отчет по task2

## Добавленные сервисы

- `booking-service`: Node.js gRPC service на `0.0.0.0:9090`, владеет `booking-db`, реализует `CreateBooking` и `ListBookings`, публикует `BookingCreated`.
- `booking-history-service`: Node.js Kafka consumer, читает topic `booking.created` consumer group `booking-history-service`, записывает события в `history-db.booking_history`.
- `booking-db`: PostgreSQL БД для новых бронирований.
- `history-db`: PostgreSQL БД для истории обработанных событий бронирования.

## Измененные и созданные файлы

- `tasks/task2/booking-service/package.json`
- `tasks/task2/booking-service/Dockerfile`
- `tasks/task2/booking-service/src/index.js`
- `tasks/task2/booking-service/src/list-bookings.js`
- `tasks/task2/booking-history-service/package.json`
- `tasks/task2/booking-history-service/Dockerfile`
- `tasks/task2/booking-history-service/src/index.js`
- `tasks/task2/docker-compose.yml`
- `tasks/task2/collect-results.sh`
- `tasks/task2/results/README.md`
- `tasks/task2/results/report.md`
- `tasks/task2/results/regress.sh`
- `hotelio-monolith/Dockerfile`
- `hotelio-monolith/src/main/java/com/hotelio/monolith/grpc/GrpcBookingClient.java`
- `hotelio-monolith/src/main/java/com/hotelio/monolith/controller/BookingController.java`

## Как запустить docker compose

```bash
docker network create hotelio-net 2>/dev/null || true
cd tasks/task2
docker compose up -d --build
```

## Как запустить тесты

```bash
cd tasks/task2/results
bash regress.sh
```

Чтобы сразу сохранить лог тестов:

```bash
cd tasks/task2
bash results/regress.sh > results/test-log.txt 2>&1
```

## Как собрать все результаты в results

```bash
cd tasks/task2
bash collect-results.sh
```

Скрипт создает или обновляет:

- `results/docker-ps.txt`;
- `results/test-log.txt`;
- `results/bookings-old-db.txt`;
- `results/bookings-new-db.txt`;
- `results/bookings-rest-monolith.txt`;
- `results/bookings-grpc-service.txt`;
- `results/booking-history.txt`.

## Команды, которые выполняет collect-results.sh

```bash
docker ps > tasks/task2/results/docker-ps.txt
curl -fsS http://localhost:8084/api/bookings > tasks/task2/results/bookings-rest-monolith.txt
docker exec -e BOOKING_GRPC_TARGET=localhost:9090 hotelio-booking-service node src/list-bookings.js > tasks/task2/results/bookings-grpc-service.txt
docker exec hotelio-db psql -U hotelio -d hotelio -c "SELECT * FROM booking ORDER BY id;" > tasks/task2/results/bookings-old-db.txt
docker exec hotelio-booking-db psql -U booking -d booking -c "SELECT * FROM bookings ORDER BY id;" > tasks/task2/results/bookings-new-db.txt
docker exec hotelio-history-db psql -U history -d history -c "SELECT * FROM booking_history ORDER BY id;" > tasks/task2/results/booking-history.txt
```

Примечание: в старой БД монолита таблица называется `booking`, а в новой БД `booking-service` — `bookings`.

## Полезные команды логов

```bash
cd tasks/task2
docker compose logs -f monolith
docker compose logs -f booking-service
docker compose logs -f booking-history-service
docker compose logs -f kafka
```
