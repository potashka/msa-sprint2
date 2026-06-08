# Task 1 Report

## Какие файлы созданы

- `tasks/task1/results/ADR.md` - ADR по миграции Hotelio от Java-монолита к микросервисам.
- `tasks/task1/results/diagram/hotelio-to-be.puml` - C4-PlantUML диаграмма целевой To-Be архитектуры.
- `tasks/task1/results/report.md` - краткий отчет и checklist по task1.

Существующие артефакты проверки сохранены:

- `tasks/task1/results/docker-ps.txt`
- `tasks/task1/results/test-log.txt`

## Команды для проверки монолита

Выполнить из корня репозитория:

```powershell
docker network create hotelio-net
```

Если сеть уже существует, Docker сообщит об этом. После этого можно продолжать.

Запуск окружения task1:

```powershell
cd tasks/task1
docker-compose up -d --build
```

Проверка контейнеров:

```powershell
docker ps
```

Проверка API монолита:

```powershell
curl http://localhost:8084/api/bookings
```

Дополнительные smoke checks:

```powershell
curl http://localhost:8084/api/users/user-123
curl http://localhost:8084/api/hotels/hotel-777
curl http://localhost:8084/api/promos/SUMMER2024
curl http://localhost:8084/api/reviews/hotel/hotel-777
```

## Где сохранить вывод docker ps и тестов

Вывод `docker ps` сохранить в:

```text
tasks/task1/results/docker-ps.txt
```

Вывод smoke tests, curl-запросов и тестовых команд сохранить в:

```text
tasks/task1/results/test-log.txt
```

## Что нужно приложить в test-log.txt

В `test-log.txt` нужно приложить:

- команду запуска окружения task1;
- ответ `curl http://localhost:8084/api/bookings`;
- ответы дополнительных smoke checks, если они выполнялись;
- вывод Gradle/application tests, если запускались тесты;
- timestamp или короткую заметку, подтверждающую доступность монолита на порту `8084`.

## Checklist

- [x] `tasks/task1/results` существует.
- [x] ADR создан.
- [x] To-Be C4-PlantUML диаграмма создана.
- [x] Report/checklist создан.
- [x] Существующие файлы проекта не удалялись.
- [x] Исходный код приложения не изменялся.
- [x] Scope ограничен task1; task2 не выполнялся.

