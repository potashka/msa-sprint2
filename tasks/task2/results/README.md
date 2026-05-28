# Task2: вынос BookingService

## Стратегия миграции данных

В task2 используется подход strangler pattern: монолит сохраняет публичный REST API и все модули, кроме создания бронирования. `POST /api/bookings` теперь делегирует создание во внешний gRPC `booking-service`, а `GET /api/bookings` продолжает читать существующую таблицу монолита, чтобы не ломать старое поведение чтения.

Существующие записи бронирований в базе монолита остаются на месте. В текущей схеме монолита таблица называется `booking`, а в новой БД сервиса таблица называется `bookings`. Для production-миграции следующим шагом нужен идемпотентный backfill из `monolith-db.booking` в `booking-db.bookings`, сверка количества и содержимого записей, а затем отдельное решение о переключении чтения на новый сервис.

## Почему у booking-service отдельная БД

`booking-service` владеет собственной PostgreSQL БД, потому что создание бронирований выделено в отдельный bounded context. Это убирает межсервисные записи в схему монолита и позволяет сервису независимо развивать схему, масштабирование, жизненный цикл деплоя и обработку отказов.

## Почему история и аналитика идут через Kafka

История бронирований относится к аудитным и аналитическим данным, поэтому ее не нужно записывать синхронно в пользовательском request path. `booking-service` публикует событие `BookingCreated` в Kafka topic `booking.created`, а `booking-history-service` читает его consumer group `booking-history-service`.

Так создание бронирования не зависит по задержке и доступности от записи истории, а в будущем к этому же событию можно подключать новые потребители без изменения booking API.

## Что остается в монолите

Монолит по-прежнему владеет:

- пользователями и проверками статуса пользователя;
- отелями и проверками доступности отеля;
- валидацией промокодов;
- отзывами и проверкой доверенности отеля;
- legacy-чтением бронирований через `GET /api/bookings`.

Новый `booking-service` вызывает эти существующие REST endpoints как anti-corruption layer для task2.

## To-Be стратегия

Следующие шаги после task2:

1. Добавить backfill job из таблицы монолита `booking` в новую таблицу `bookings`.
2. После сверки данных переключить `GET /api/bookings` на чтение через `booking-service.ListBookings`.
3. Добавить outbox table в `booking-db`, если потребуется более строгая гарантия публикации событий.
4. Добавить health checks, метрики, tracing и retry budgets вокруг REST-зависимостей от монолита.
5. Постепенно выносить promo, hotel, review и user capabilities только после стабилизации их границ.

## Фиксация результатов для сдачи

Все артефакты собираются скриптом:

```bash
cd tasks/task2
bash collect-results.sh
```

Скрипт не удаляет контейнеры и БД. Он запускает `results/regress.sh`, сохраняет лог тестов, затем фиксирует состояние контейнеров, REST/gRPC листинги и SQL select'ы.

После запуска в `tasks/task2/results` должны быть файлы:

- `docker-ps.txt` — результат `docker ps`;
- `regress.sh` — доработанный регрессионный тест для task2;
- `test-log.txt` — лог выполнения тестовых запросов;
- `bookings-old-db.txt` — `SELECT * FROM booking` из старой БД монолита;
- `bookings-new-db.txt` — `SELECT * FROM bookings` из новой БД `booking-service`;
- `bookings-rest-monolith.txt` — результат `GET http://localhost:8084/api/bookings`;
- `bookings-grpc-service.txt` — результат прямого gRPC вызова `ListBookings`;
- `booking-history.txt` — `SELECT * FROM booking_history` из БД истории;
- `README.md` и `report.md` — описание решения и команд.
