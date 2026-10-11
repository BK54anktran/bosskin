# Backend BossKin — image chạy production (Vibe Host / VPS / bất kỳ nền tảng Docker).
# Cấu hình hoàn toàn qua biến môi trường (danh sách: docs/runbook.md mục 2, docs/he-thong/trien-khai.md).
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -B dependency:go-offline -q
COPY src ./src
RUN mvn -B clean package -DskipTests -q

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
# Chạy bằng user thường; thư mục dữ liệu cho tài liệu nhân sự (DOCUMENTS_STORAGE=local) và cache ô bản đồ
RUN addgroup -S app && adduser -S app -G app && mkdir -p /data/documents /data/map-tiles && chown -R app:app /data
COPY --from=build /app/target/*.jar app.jar
USER app
ENV PORT=8080 \
    SPRING_PROFILES_ACTIVE=prod \
    TZ=Asia/Ho_Chi_Minh \
    DOCUMENTS_LOCAL_DIR=/data/documents \
    MAP_TILE_CACHE_DIR=/data/map-tiles \
    JAVA_OPTS="-XX:MaxRAMPercentage=75"
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=3 \
  CMD wget -qO- http://127.0.0.1:${PORT}/actuator/health >/dev/null || exit 1
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
