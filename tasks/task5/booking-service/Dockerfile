FROM golang:1.21-alpine AS build

WORKDIR /src
COPY main.go .
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/booking-service main.go

FROM alpine:3.19

RUN apk add --no-cache wget
WORKDIR /app
COPY --from=build /out/booking-service /app/booking-service

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:8080/ping || exit 1

CMD ["/app/booking-service"]
