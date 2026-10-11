# Bản web BossKin — build Flutter web rồi phục vụ bằng Nginx.
#   docker build --build-arg API_HOST=https://api.ten-mien.vn -t bosskin-web frontend/
# API_HOST là địa chỉ backend (bản release không cho đổi server lúc chạy).
FROM ghcr.io/cirruslabs/flutter:3.47.6 AS build
ARG API_HOST
WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get
COPY . .
RUN test -n "$API_HOST" || (echo "Thiếu --build-arg API_HOST" && exit 1) \
 && flutter build web --release --dart-define=API_HOST=$API_HOST

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 8080
