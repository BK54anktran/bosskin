# Trang giới thiệu + trang trợ giúp (/help/) bằng Nginx — cho Vibe Host / nền tảng Docker (Netlify dùng netlify.toml, không dùng file này).
# Ngữ cảnh build là thư mục landing/ nên trang trợ giúp (help/ ở gốc repo) được lấy từ GitHub lúc build.
FROM alpine/git:latest AS help
ARG REPO=https://github.com/BK54anktran/bosskin.git
ARG BRANCH=main
# Tệp này đổi theo mỗi commit trên nhánh → lớp clone bên dưới không bị dùng lại từ cache cũ
ADD https://github.com/BK54anktran/bosskin/commits/main.atom /tmp/rev.atom
RUN git clone --depth 1 --filter=blob:none --sparse -b $BRANCH $REPO /src \
 && cd /src && git sparse-checkout set help \
 && mkdir -p /out && cp help/*.html /out/ && cp -r help/img /out/

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY . /usr/share/nginx/html
COPY --from=help /out /usr/share/nginx/html/help
RUN cd /usr/share/nginx/html && rm -f Dockerfile nginx.conf
EXPOSE 8080 3000
