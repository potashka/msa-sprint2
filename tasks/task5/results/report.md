# Отчет по task5

## Что сделано

- Подготовлен отдельный `tasks/task5/booking-service` на основе task4, не изменяя task4.
- `GET /ping` возвращает различимые ответы:
  - v1: `pong from v1`;
  - v2: `pong from v2`.
- Добавлен Helm chart для деплоя двух версий:
  - `values-v1.yaml`: `version: v1`, `ENABLE_FEATURE_X=false`, `SERVICE_VERSION=v1`;
  - `values-v2.yaml`: `version: v2`, `ENABLE_FEATURE_X=true`, `SERVICE_VERSION=v2`.
- Deployment labels содержат:
  - `app: booking-service`;
  - `version: v1` или `version: v2`.
- Service `booking-service` выбирает только `app: booking-service` и не фиксирует `version`.
- Добавлены Istio manifests:
  - `VirtualService` для header routing и canary 90/10;
  - `DestinationRule` с subsets `v1`/`v2`, connection pool и outlier detection;
  - `EnvoyFilter` как учебный extension-артефакт.

## Установка Istio

```bash
istioctl install --set profile=demo -y
kubectl label namespace default istio-injection=enabled --overwrite
```

После включения sidecar injection перезапусти workloads, если они были созданы до установки label.

## Сборка и загрузка image в Minikube

Запускать из `tasks/task5`:

```bash
docker build -t booking-service:latest ./booking-service
minikube image load booking-service:latest
```

Внешний Docker Registry не используется.

## Деплой v1/v2

```bash
helm upgrade --install booking-service-v1 ./helm/booking-service \
  -f ./helm/booking-service/values-v1.yaml

helm upgrade --install booking-service-v2 ./helm/booking-service \
  -f ./helm/booking-service/values-v2.yaml

kubectl rollout status deployment/booking-service-v1
kubectl rollout status deployment/booking-service-v2
```

## Применение Istio manifests

```bash
kubectl apply -f ./istio/destination-rule.yaml
kubectl apply -f ./istio/virtual-service.yaml
kubectl apply -f ./istio/envoy-filter.yaml
```

## Canary 90% / 10%

`VirtualService` содержит default route:

- 90% на subset `v1`;
- 10% на subset `v2`.

Проверка:

```bash
./check-canary.sh
```

Скрипт выполняет серию запросов из pod с sidecar и считает ответы `pong from v1` / `pong from v2`.

## Feature flag routing

Если запрос содержит header:

```text
X-Feature-Enabled: true
```

`VirtualService` отправляет 100% трафика на subset `v2`.

Проверка:

```bash
./check-feature-flag.sh
```

## Retry

Retry настроен в `VirtualService`:

```yaml
retries:
  attempts: 3
  perTryTimeout: 2s
  retryOn: 5xx,connect-failure,refused-stream
```

## Circuit breaking

Circuit breaking настроен в `DestinationRule`:

- `connectionPool.tcp.maxConnections`;
- `connectionPool.http.http1MaxPendingRequests`;
- `connectionPool.http.maxRequestsPerConnection`;
- `outlierDetection.consecutive5xxErrors`;
- `outlierDetection.baseEjectionTime`.

## EnvoyFilter

Фактическая маршрутизация по `X-Feature-Enabled: true` реализована в `VirtualService`. `EnvoyFilter` добавлен как минимальный учебный артефакт расширения Envoy: он добавляет response header `x-feature-routing-demo` для workloads `app=booking-service`.

## Fallback: результаты теста

Тест запущен командой:

```bash
RUN_FALLBACK_TEST=true ./check-fallback.sh | tee results/check-fallback-log.txt
```

Скрипт масштабирует `booking-service-v1` до 0 реплик, отправляет 20 запросов из pod с sidecar, затем восстанавливает v1.

**Результат:** из 20 запросов 3 вернули `pong from v2`, остальные 17 — пустой ответ (connection failure).

**Что это означает:** 3/20 ≈ 10% — в точности соответствует весу subset v2 в canary route. Запросы, направленные на subset v1 (90%), получали connection failure, потому что у v1 не было живых endpoints. Ретраи (`retryOn: connect-failure`) повторяли попытку на том же subset v1 и тоже падали.

**Вывод по механике fallback в Istio:**

Retry + outlier detection защищают от **transient failures** отдельных pod: если один pod v1 возвращает 5xx, outlier detection его eject'ит, следующий запрос уходит на другой endpoint v1. Это работает.

При **полном отсутствии endpoints** в subset (scale to 0) Envoy не переключается на другой subset автоматически — веса VirtualService фиксированы. Чтобы реализовать полный failover v1 → v2, потребовалась бы отдельная политика: например, priority-based routing или изменение весов через внешний контроллер при обнаружении недоступности subset.

Для задания это поведение задокументировано и протестировано. Скриншот результата теста сохранён в `results/`.

## Фиксация результатов для сдачи

```bash
mkdir -p results

./check-istio.sh | tee results/check-istio-log.txt
./check-canary.sh | tee results/check-canary-log.txt
./check-feature-flag.sh | tee results/check-feature-flag-log.txt
./check-fallback.sh | tee results/check-fallback-log.txt

kubectl get pods > results/kubectl-get-pods.txt
kubectl get svc > results/kubectl-get-svc.txt
kubectl get virtualservices > results/virtualservices.txt
kubectl get destinationrules > results/destinationrules.txt
```

## Файлы в results

- `values-v1.yaml`;
- `values-v2.yaml`;
- `virtual-service.yaml`;
- `destination-rule.yaml`;
- `envoy-filter.yaml`;
- `report.md`.
