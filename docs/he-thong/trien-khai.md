# Triển khai & vận hành

Chi tiết từng thao tác vận hành ở [runbook](../runbook.md); dựng hạ tầng ở [infra/aws/README.md](../../infra/aws/README.md).
Trang này là bản đồ tổng.

## Môi trường

| Môi trường | Backend | Frontend | DB | Ghi chú |
|---|---|---|---|---|
| Dev (máy chủ dự án, Windows) | `dev\start.cmd backend` → cổng 8080, đọc `backend/.env` | `dev\start.cmd frontend` → web debug cổng 3000 | MySQL local 3306 | Script ở `dev/`; dữ liệu mẫu `dev\seed-th.cmd`. Không reset DB khi chưa được chủ dự án đồng ý |
| Test tự động | Testcontainers MySQL | `flutter test` | container tạm | CI GitHub Actions |
| Prod (AWS) | Elastic Beanstalk Java 17 (cổng 5000 sau ALB, profile `prod`) | Web tĩnh build với `API_HOST` | RDS MySQL 8 | Stack CloudFormation `infra/aws/bosskin.yaml` |

## Cấu hình

Toàn bộ qua biến môi trường (danh sách đầy đủ: [runbook](../runbook.md) mục 2).
Bắt buộc ở prod: `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET`, `CORS_ALLOWED_ORIGINS`. Nên có: `AWS_S3_BUCKET`,
`FIREBASE_SERVICE_ACCOUNT_JSON`. Lần đầu: `BOOTSTRAP_SYSADMIN_EMAIL/PASSWORD` (mật khẩu ≥ 12 ký tự) để tạo quản trị hệ thống đầu tiên.

Frontend chỉ cần `--dart-define=API_HOST=https://api.<tên-miền>` lúc build; bản release không cho đổi server.

## Build và phát hành

| Việc | Lệnh / workflow |
|---|---|
| Test backend | `cd backend && ./mvnw test` · CI `test.yml` khi push `main` + PR (đang tắt trên GitHub) |
| Đóng gói backend | `./mvnw -DskipTests package` → `target/*.jar` |
| Deploy backend | GitHub Actions **Deploy to Elastic Beanstalk** (`deploy.yml`, chạy tay), nhãn phiên bản = mã commit |
| Build web | `flutter build web --release --dart-define=API_HOST=…` · CI `frontend-build.yml` |
| App Android | runbook mục 10 |
| Kiểm hạ tầng | `cfn-lint infra/aws/bosskin.yaml` · CI `infra-lint.yml` |
| Trang trợ giúp | `python3 help/tools/build_help.py` → `help/*.html`, host tĩnh bất kỳ ([help/README.md](../../help/README.md)) |
| Tài liệu tự sinh | `python3 tools/docs/gen_he_thong.py [--check]` |

Migration: thêm `V<n>__mo_ta.sql`, không sửa file đã chạy. Flyway tự chạy khi app khởi động (`validate-on-migrate`, cấm `clean` ở prod).
Bản có migration mới → **snapshot RDS trước khi deploy** (runbook mục 3–4: rollback = sửa tiến hoặc khôi phục snapshot).

## Vibe Host (Mắt Bão)

Phương án thay cho AWS (11/10/2026). Hai ứng dụng Docker + MySQL 8 do Vibe Host cấp — tạo **hai website** riêng, hoặc một **cụm**
từ `docker-compose.yml` ở gốc repo (api + web, ổ `bosskin-data` cho `/data`, giới hạn 1 GB cho api):

| Ứng dụng | Thư mục build | Cổng | Ghi chú |
|---|---|---|---|
| API | `backend/` (`backend/Dockerfile`) | 8080 | Profile `prod`, health `GET /actuator/health`, chạy user thường, dữ liệu file ở `/data` |
| Web | `frontend/` (`frontend/Dockerfile`, Nginx) | 8080 (và 3000 — cổng Vibe Host tự chọn) | Biến môi trường **`API_HOST`** = địa chỉ công khai của API (vd `https://api.<tên-miền>`), đọc lúc chạy qua `env.js` — không cần build lại khi đổi. Image tải gói web CI build sẵn (release `web-latest`); build từ mã nguồn: `frontend/Dockerfile.build` |

Biến môi trường của API (bí mật đặt ở mục biến môi trường của Vibe Host, không commit):

| Biến | Giá trị |
|---|---|
| `DB_URL` | `jdbc:mysql://<host>:<port>/<db>?sslMode=PREFERRED&serverTimezone=Asia/Ho_Chi_Minh&characterEncoding=UTF-8` — DB phải là **MySQL 8**, **trống** (Flyway tự tạo 50 bảng lần đầu) |
| `DB_USERNAME`, `DB_PASSWORD` | Tài khoản DB do Vibe Host cấp |
| `JWT_SECRET` | ≥ 32 byte ngẫu nhiên (`openssl rand -base64 48`); thiếu thì app không khởi động |
| `CORS_ALLOWED_ORIGINS` | Địa chỉ bản web + trang giới thiệu, cách dấu phẩy |
| `BOOTSTRAP_SYSADMIN_EMAIL`, `BOOTSTRAP_SYSADMIN_PASSWORD` | Lần đầu (mật khẩu ≥ 12 ký tự); xoá sau khi đăng nhập `/admin` và cài 2FA |
| `DOCUMENTS_STORAGE` | `local` nếu không có kho S3 — cần gắn **ổ lưu trữ bền** vào `/data`, nếu không file mất khi deploy lại |
| `AWS_S3_ENDPOINT`, `AWS_S3_BUCKET`, `AWS_ACCESS_KEY`, `AWS_SECRET_KEY`, `AWS_REGION` | Kho tương thích S3 (MinIO / object storage) cho ảnh đại diện, file Excel lịch sử. Không có thì tải ảnh lên báo lỗi |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Nên có (thông báo đẩy) |

Đang chạy (11/10/2026): API `https://api.bosskin.io.vn`, bản web `https://app.bosskin.io.vn`, trang giới thiệu + trợ giúp `https://bosskin.io.vn`
(website `landing/`, xem `landing/README.md`). Tên miền gắn ở trang quản lý Vibe Host; đổi tên miền → sửa `API_HOST` (web), `CORS_ALLOWED_ORIGINS` (API),
`appUrl` trong `landing/site-config.js`; tên miền trang giới thiệu còn ở `SITE` (`help/tools/build_help.py`, sinh canonical + `sitemap.xml`),
canonical / `og:url` của `landing/index.html` và `landing/robots.txt`. Sơ đồ trang gửi ở Google Search Console (xem `landing/README.md`).

Thông báo đẩy trên **bản web** (FCM Web Push): đặt cho website Web 5 biến `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_APP_ID`, `FIREBASE_WEB_SENDER_ID`,
`FIREBASE_WEB_PROJECT_ID`, `FIREBASE_WEB_VAPID_KEY` (Firebase Console → Project settings: mục Your apps → Web app; tab Cloud Messaging → Web Push
certificates). Đủ cả 5 mới bật; `docker/40-env.sh` ghi vào `env.js`, cả trang lẫn `firebase-messaging-sw.js` đọc từ đó. Đây là cấu hình công khai,
không phải bí mật. iPhone chỉ nhận khi đã thêm BossKin ra màn hình chính (iOS 16.4+). Mỗi tài khoản vẫn chỉ gắn một thiết bị nhận thông báo.
Thông báo luôn do `firebase-messaging-sw.js` hiện ngay trong sự kiện `push` (cả khi trang đang mở); trang chỉ ghi vào hộp thông báo. Đừng chuyển
việc hiện thông báo về phía trang: Safari coi lần đẩy không hiện thông báo trong sự kiện `push` là đẩy im lặng, đủ 3 lần thì huỷ đăng ký
(máy chủ vẫn ghi `SUCCESS` ở `fcm_notification_logs` nhưng máy không nhận nữa cho tới khi lưu lại cài đặt thông báo).

Lưu ý khi tạo trên Vibe Host:
- **Cập nhật API:** push `main` → chờ workflow **API jar** (`.github/workflows/api-jar.yml`, ~3 phút) cập nhật file `bosskin-api.jar` ở release `api-latest` → bấm triển khai lại. `backend/Dockerfile` chỉ tải file đó về (không chạy Maven): Vibe Host chờ bước build ~5 phút, build Maven từ đầu thường vượt mốc và báo `fetch failed` (11/10/2026, sau khi thêm biến S3). Build từ mã nguồn tại chỗ: `backend/Dockerfile.build`.
- **Cập nhật bản web:** cùng cách — push `main` → chờ workflow **Frontend build** chạy xong bước "Đăng gói web lên release web-latest" (file `bosskin-web.tar.gz`, có trước bước build APK) → bấm triển khai lại website Web. `frontend/Dockerfile` chỉ tải gói đó về và chạy Nginx: cài Flutter + build web trên máy build của Vibe Host vượt mốc ~5 phút (`fetch failed` 3 lần liên tiếp, 12/10/2026).
- **`DB_URL` ghi dạng `mysql://<host>:<port>/<db>?…`** (bỏ `jdbc:` — nền tảng chỉ nhận `scheme://`); image tự thêm `jdbc:` lúc khởi động.
- **CSDL: không tạo tay.** Khi tạo website API, Vibe Host quét thấy app cần MySQL, tự tạo CSDL `<tên website>-db` (MySQL 8.0, "primary") và tiêm `DB_URL` (dạng `mysql://…`), `DB_PASSWORD`, `MYSQL_*`… — app dùng luôn (`backend/docker/entrypoint.sh` thêm `jdbc:`). Đừng tạo CSDL riêng rồi đặt `DB_URL` tay: nền tảng vẫn tạo cái của nó thành hai CSDL, và xoá cái "primary" khi website đang chạy làm nó kẹt "Đang triển khai", hỏng mọi lượt deploy sau (11/10/2026 — phải xoá website tạo lại).
- Khoá tuỳ chọn trong `backend/.env.example` để dạng chú thích: nền tảng quét file này và coi khoá trống là bắt buộc.
- **RAM của API ≥ 1 GB** (mặc định 512 MB chỉ còn ~384 MB heap, dễ hết bộ nhớ khi nhập Excel / tính lương).
- **Khai `/data` là thư mục dữ liệu bền** của website API ngay sau khi tạo.
- **Repo riêng tư:** cổng agent của Vibe Host chỉ nhận repo Git công khai — hỏi Vibe Host cách nối repo riêng tư (deploy key / token),
  không chuyển repo sang công khai.

Sau khi chạy: `curl https://<api>/actuator/health` → `UP`; đăng nhập `/admin` bằng tài khoản bootstrap; tạo công ty; trỏ `appUrl` trong
`landing/site-config.js` tới bản web để hiện nút Đăng nhập. Sao lưu DB: dùng tính năng sao lưu của Vibe Host nếu có, và tải bản dump định kỳ
về nơi khác (runbook mục 5).

## Vận hành hằng ngày

Bảng dưới viết cho AWS; trên Vibe Host: sức khoẻ = healthcheck của container + `/actuator/health`, log xem ở trang Vibe Host
(hoặc công cụ đọc log của cổng agent), sao lưu = bản sao lưu CSDL của Vibe Host + dump định kỳ về nơi khác, không có cảnh báo SNS
(dùng UptimeRobot hoặc tương tự gọi `/actuator/health`).


| Việc | Ở đâu |
|---|---|
| Sức khoẻ | `GET /actuator/health`; cảnh báo SNS (CPU / dung lượng RDS, EB không ổn) |
| Log | CloudWatch (30 ngày); tra theo mã request `rid` người dùng gửi kèm lỗi |
| Sao lưu | RDS tự sao lưu 7 ngày + snapshot tay trước migration; diễn tập khôi phục `tools/ops/backup_restore_drill.sh` (runbook mục 5) |
| Việc chạy nền | 6 job trong app (nhắc ca, nhắc chấm công, cộng phép, áp quá trình công tác, báo HĐ / tài liệu hết hạn) — [kiến trúc](kien-truc.md#việc-chạy-nền) |
| Thông số luật | Thuế TNCN / BH / lương tối thiểu vùng / ngày lễ mẫu: quản trị hệ thống cập nhật ở `/admin` (runbook mục 13) |
| Khách hàng mới | Tạo công ty ở `/admin`, chuyển dữ liệu theo [chuyen-du-lieu.md](../chuyen-du-lieu.md), nghiệm thu theo [uat-kich-ban.md](../uat-kich-ban.md) |
| Tài khoản | Đặt lại mật khẩu, gỡ 2FA, xuất mật khẩu tạm: runbook mục 11, 14 |

## Giới hạn hiện tại cần biết

- Job chạy nền chạy trên mọi máy EB → trước khi tăng lên > 1 máy cần khoá phân tán.
- Cache ô bản đồ nằm trên đĩa máy app (mất khi thay máy — chỉ ảnh hưởng tốc độ).
- Một DB chung cho mọi công ty: sao lưu / khôi phục là theo toàn hệ thống, không theo từng công ty.
