# Task4: Docker, Helm и CI/CD для booking-service

## Что входит в task4

- Go HTTP service `booking-service` на порту `8080`;
- Docker multi-stage image;
- Helm chart `helm/booking-service`;
- staging/prod values;
- GitLab CI/CD pipeline для локального `gitlab-ci-local`;
- скрипты проверки статуса и Kubernetes DNS.

## Локальная сборка Docker

```bash
cd tasks/task4
docker build -t booking-service:latest ./booking-service
```

Проверка контейнера:

```bash
docker run -d --name booking-service-local -p 8080:8080 booking-service:latest
curl http://localhost:8080/ping
curl http://localhost:8080/ready
docker rm -f booking-service-local
```

Проверка feature flag:

```bash
docker run -d --name booking-service-feature -p 8080:8080 -e ENABLE_FEATURE_X=true booking-service:latest
curl http://localhost:8080/feature
docker rm -f booking-service-feature
```

## Minikube и Helm

```bash
minikube start --driver=docker
docker build -t booking-service:latest ./booking-service
minikube image load booking-service:latest
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

```bash
./check-status.sh
./check-dns.sh
```

Ручная проверка через port-forward:

```bash
kubectl port-forward svc/booking-service 8080:80
curl http://localhost:8080/ping
curl http://localhost:8080/ready
curl http://localhost:8080/feature
```

DNS-проверка внутри кластера выполняет:

```bash
wget -qO- http://booking-service/ping
```

## GitLab CI local

```bash
gitlab-ci-local build test deploy tag
```

Pipeline не использует внешний registry. Deploy stage загружает локальный образ в Minikube через `minikube image load` и устанавливает chart с `imagePullPolicy=Never`.

## Results

В `tasks/task4/results` подготовлены:

- `values-staging.yaml`;
- `values-prod.yaml`;
- `.gitlab-ci.yml`;
- `report.md`.

Рекомендуемые логи для сдачи перечислены в `tasks/task4/results/report.md`.
