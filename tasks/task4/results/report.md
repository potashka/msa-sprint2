# Отчет по task4

## Изменения

- Реализован `booking-service` как простой Go HTTP server без внешних зависимостей.
- Добавлены endpoints:
  - `GET /ping` -> `pong`;
  - `GET /ready` -> `ready`;
  - `GET /feature` -> сообщение о включенной feature при `ENABLE_FEATURE_X=true`, иначе `404 feature disabled`.
- Добавлено логирование старта сервиса и значения `ENABLE_FEATURE_X`.
- Dockerfile переделан на multi-stage build: builder `golang:1.21-alpine` и runtime `alpine`.
- В Helm chart добавлены Deployment и Service со стабильными labels `app=booking-service`.
- Добавлены default, staging и prod values.
- Добавлен GitLab CI/CD pipeline со стадиями `build`, `test`, `deploy`, `tag`.
- Обновлены `check-dns.sh` и `check-status.sh` для неинтерактивной проверки в локальном Minikube.

## Сборка Docker

Запускать из `tasks/task4`:

```bash
docker build -t booking-service:latest ./booking-service
```

Локальная smoke-проверка контейнера:

```bash
docker run -d --rm --name booking-service-local -p 8080:8080 booking-service:latest
curl --fail http://localhost:8080/ping
curl --fail http://localhost:8080/ready
docker rm -f booking-service-local
```

Проверка feature flag:

```bash
docker run -d --rm --name booking-service-feature -p 8080:8080 -e ENABLE_FEATURE_X=true booking-service:latest
curl --fail http://localhost:8080/feature
docker rm -f booking-service-feature
```

## Minikube

```bash
minikube start --driver=docker
docker build -t booking-service:latest ./booking-service
minikube image load booking-service:latest
```

## Helm deploy

Локальный deploy со значениями по умолчанию:

```bash
helm upgrade --install booking-service ./helm/booking-service \
  --set image.name=booking-service \
  --set image.tag=latest \
  --set image.pullPolicy=Never
```

Staging:

```bash
helm upgrade --install booking-service ./helm/booking-service \
  -f ./helm/booking-service/values-staging.yaml
```

Prod:

```bash
helm upgrade --install booking-service ./helm/booking-service \
  -f ./helm/booking-service/values-prod.yaml
```

## Проверки

Статус Deployment, Service и Helm release:

```bash
./check-status.sh
```

Ручная проверка через port-forward:

```bash
kubectl port-forward svc/booking-service 8080:80
curl http://localhost:8080/ping
curl http://localhost:8080/ready
```

Проверка DNS внутри кластера:

```bash
./check-dns.sh
```

Команда, которая выполняется во временном pod:

```bash
wget -qO- http://booking-service/ping
```

## gitlab-ci-local

Запускать из `tasks/task4`:

```bash
gitlab-ci-local build test deploy tag
```

Deploy stage использует:

```bash
minikube image load booking-service:${IMAGE_TAG}
helm upgrade --install booking-service ./helm/booking-service --set image.name=booking-service --set image.tag=${IMAGE_TAG} --set image.pullPolicy=Never
```

Tag stage не пушит тег автоматически, а выводит безопасную команду:

```bash
git tag task4-YYYYMMDDHHMMSS && git push origin task4-YYYYMMDDHHMMSS
```

## Что сохранить в results как логи

При сдаче можно сохранить такие выводы в `tasks/task4/results`:

```bash
docker build -t booking-service:latest ./booking-service | tee results/docker-build.txt
helm template booking-service ./helm/booking-service | tee results/helm-template.txt
kubectl get pods -l app=booking-service -o wide | tee results/kubectl-pods.txt
kubectl get svc booking-service | tee results/kubectl-svc.txt
helm list | tee results/helm-list.txt
./check-dns.sh | tee results/check-dns.txt
./check-status.sh | tee results/check-status.txt
gitlab-ci-local build test deploy tag | tee results/gitlab-ci-local.txt
```

## Фактически подготовленные файлы результатов

- `report.md` — описание изменений и решений.
- `values-staging.yaml` — staging values.
- `values-prod.yaml` — prod values.
- `.gitlab-ci.yml` — копия финального pipeline.
- `docker-build.txt` — лог успешной сборки Docker image.
- `helm-template.txt` — отрендеренный Helm manifest.
- `helm-upgrade.txt` — лог установки Helm release.
- `kubectl-rollout.txt` — лог успешного rollout Deployment.
- `kubectl-get-pods-services.txt` — `kubectl get pods` и `kubectl get services`.
- `curl-ping.txt` — успешный curl на `/ping` и `/ready` через port-forward.
- `check-dns.txt` — успешная проверка Kubernetes DNS через временный pod.
- `check-status.txt` — вывод `./check-status.sh`.
- `docker-image-ls.txt` — `docker image ls booking-service`.
- `minikube-image-list.txt` — `minikube image list` для `booking-service`.
- `image-lists.txt` — объединенный вывод `docker image ls` и `minikube image list`.

Скриншоты для сдачи можно сделать вручную по уже сохраненным логам:

- успешный curl на `/ping`: `curl-ping.txt`;
- `./check-dns.sh`: `check-dns.txt`;
- `./check-status.sh`: `check-status.txt`.
