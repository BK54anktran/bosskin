# Backend BossKin — image chạy production (Vibe Host / VPS / bất kỳ nền tảng Docker).
# Cấu hình hoàn toàn qua biến môi trường (danh sách: docs/runbook.md mục 2, docs/he-thong/trien-khai.md).
#
# KHÔNG chạy Maven ở đây: file chạy được GitHub Actions đóng gói sẵn (.github/workflows/api-jar.yml → release "api-latest")
# và tải về lúc build image. Lý do: Vibe Host chỉ chờ bước build ~5 phút, build Maven từ đầu thường vượt mốc đó (fetch failed).
# Quy trình: push main → chờ workflow "API jar" xanh → triển khai lại. Muốn build từ mã nguồn tại chỗ: Dockerfile.build.
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
ARG JAR_URL=https://github.com/BK54anktran/bosskin/releases/download/api-latest/bosskin-api.jar
ADD ${JAR_URL} /app/app.jar
# Chạy bằng user thường; thư mục dữ liệu cho tài liệu nhân sự (DOCUMENTS_STORAGE=local) và cache ô bản đồ
# Quyền đặt lại tại đây: máy build có thể lấy mã nguồn với umask chặt (14/10/2026: entrypoint.sh "Permission denied" khi chạy bằng user app)
COPY docker/entrypoint.sh /app/entrypoint.sh
RUN addgroup -S app && adduser -S app -G app && mkdir -p /data/documents /data/map-tiles && chown -R app:app /data \
 && chmod 644 /app/app.jar && chmod 755 /app/entrypoint.sh
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
# Biến kết nối CSDL: xem docker/entrypoint.sh (CSDL nền tảng cấp qua MYSQL_*, hoặc DB_URL dạng jdbc:mysql:// / mysql://)
ENTRYPOINT ["sh", "/app/entrypoint.sh"]
