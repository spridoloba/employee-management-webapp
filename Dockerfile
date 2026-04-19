# syntax=docker/dockerfile:1.7
# ------------------------------------------------------------------
# Stage 1 — build
# ------------------------------------------------------------------
FROM maven:3.9-eclipse-temurin-17-alpine AS build
WORKDIR /build

COPY pom.xml .
RUN mvn -B -e -q dependency:go-offline

COPY src ./src
RUN mvn -B -e -DskipTests package && \
    mv target/*.jar target/app.jar

# ------------------------------------------------------------------
# Stage 2 — extract Spring Boot layers for better image caching
# ------------------------------------------------------------------
FROM eclipse-temurin:17-jre-alpine AS extractor
WORKDIR /extract
COPY --from=build /build/target/app.jar app.jar
RUN java -Djarmode=layertools -jar app.jar extract

# ------------------------------------------------------------------
# Stage 3 — runtime
# ------------------------------------------------------------------
FROM eclipse-temurin:17-jre-alpine AS runtime

RUN apk add --no-cache wget tini && \
    addgroup -g 10001 -S appgroup && \
    adduser  -u 10001 -S appuser -G appgroup

WORKDIR /app

COPY --from=extractor --chown=appuser:appgroup /extract/dependencies/          ./
COPY --from=extractor --chown=appuser:appgroup /extract/spring-boot-loader/    ./
COPY --from=extractor --chown=appuser:appgroup /extract/snapshot-dependencies/ ./
COPY --from=extractor --chown=appuser:appgroup /extract/application/           ./

USER 10001:10001

EXPOSE 8080

ENV JAVA_OPTS="-XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError"

HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
  CMD wget -qO- "http://127.0.0.1:${APP_PORT:-8080}/actuator/health" \
      | grep -q '"status":"UP"' || exit 1

ENTRYPOINT ["/sbin/tini", "--", "sh", "-c", "exec java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher \"$@\"", "--"]
