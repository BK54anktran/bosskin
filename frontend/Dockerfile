# Bản web BossKin — phục vụ bằng Nginx gói web đã build sẵn.
# Địa chỉ backend: đặt biến môi trường API_HOST cho container lúc chạy (ghi vào env.js, không cần build lại).
#
# KHÔNG build Flutter ở đây: gói web được GitHub Actions build sẵn (.github/workflows/frontend-build.yml → release "web-latest")
# và tải về lúc build image. Lý do: Vibe Host chỉ chờ bước build ~5 phút, cài Flutter + build web từ đầu vượt mốc đó (fetch failed).
# Quy trình: push main → chờ workflow "Frontend build" đăng xong gói web → triển khai lại. Muốn build từ mã nguồn tại chỗ: Dockerfile.build.
FROM nginx:1.27-alpine
ARG WEB_URL=https://github.com/BK54anktran/bosskin/releases/download/web-latest/bosskin-web.tar.gz
ADD ${WEB_URL} /tmp/bosskin-web.tar.gz
RUN rm -rf /usr/share/nginx/html/* \
 && tar -xzf /tmp/bosskin-web.tar.gz -C /usr/share/nginx/html \
 && rm /tmp/bosskin-web.tar.gz \
 && chmod -R a+rX /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/40-env.sh /docker-entrypoint.d/40-env.sh
RUN chmod 644 /etc/nginx/conf.d/default.conf && chmod 755 /docker-entrypoint.d/40-env.sh
ENV API_HOST=
EXPOSE 8080 3000
