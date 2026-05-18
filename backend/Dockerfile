# syntax=docker/dockerfile:1

###############################################################################
# Stage 1 — Build
# Uses a Maven + Temurin JDK 21 image. Dependencies are resolved in a separate
# layer so they are cached unless pom.xml changes.
###############################################################################
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build

COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q clean package -DskipTests

###############################################################################
# Stage 2 — Runtime
# Minimal JRE image. Runs as a non-root user with a tuned JVM and a healthcheck.
###############################################################################
FROM eclipse-temurin:21-jre-jammy AS runtime

# Create an unprivileged user.
RUN groupadd --system app && useradd --system --gid app --home /app app

WORKDIR /app
COPY --from=build /build/target/app.jar /app/app.jar

# curl is used by the container HEALTHCHECK.
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

USER app

ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+UseG1GC -XX:+ExitOnOutOfMemoryError"
ENV SERVER_PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=15s --timeout=5s --start-period=70s --retries=8 \
    CMD curl -fsS http://localhost:8080/actuator/health/liveness || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
