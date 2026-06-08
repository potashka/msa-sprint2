FROM gradle:8.7-jdk17 AS build
WORKDIR /workspace
COPY . .
RUN ./gradlew bootJar --no-daemon

FROM eclipse-temurin:17-jdk-jammy
WORKDIR /app
COPY --from=build /workspace/build/libs/hotelio-monolith-1.0.0.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
