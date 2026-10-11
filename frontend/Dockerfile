# Bản web BossKin — build Flutter web rồi phục vụ bằng Nginx.
# Địa chỉ backend: đặt biến môi trường API_HOST cho container lúc chạy (ghi vào env.js, không cần build lại);
# hoặc truyền --build-arg API_HOST=... để gắn cứng lúc build.
FROM ghcr.io/cirruslabs/flutter:3.47.6 AS build
ARG API_HOST=
WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get
COPY . .
RUN flutter build web --release --dart-define=API_HOST=$API_HOST

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY docker/40-env.sh /docker-entrypoint.d/40-env.sh
RUN chmod +x /docker-entrypoint.d/40-env.sh
COPY --from=build /app/build/web /usr/share/nginx/html
ENV API_HOST=
EXPOSE 8080
