# Bosskin — Hướng dẫn cài đặt & chạy

## Yêu cầu hệ thống

| Công cụ | Phiên bản |
|---|---|
| Java | 17 |
| Maven | 3.8+ |
| Flutter | 3.x (Dart SDK ≥ 3.0) |
| Docker & Docker Compose | 20+ |
| Python | 3.x (để serve frontend) |

---

## 1. Clone dự án

```bash
git clone <repo-url>
cd flutter-bosskin
```

---

## 2. Chạy nhanh môi trường dev (Windows)

Yêu cầu: MySQL đang chạy ở `localhost:3306` (database `bosskin`), file `backend\.env` đã điền (mẫu: `backend\.env.example`).

```bat
dev\start.cmd              :: backend (8080) + frontend (3000), chạy nền
dev\start.cmd backend      :: chỉ backend
dev\status.cmd             :: trạng thái + log cuối
dev\stop.cmd               :: dừng tất cả   (dev\stop.cmd -Force: dừng cả tiến trình lạ chiếm cổng)
dev\reset-db.cmd           :: XOÁ SẠCH DB dev, chạy lại migration, tạo system admin (BOOTSTRAP_SYSADMIN_* trong .env)
dev\seed-th.cmd            :: tạo công ty mẫu "TH company" (cần backend đang chạy; mật khẩu = SEED_USER_PASSWORD trong .env)
```

- Backend: `mvn spring-boot:run` trong `backend\` (dùng `mvnw.cmd` nếu chưa có `mvn`), đọc `backend\.env`.
  Flyway tự chạy migration khi khởi động. Log: `dev\logs\backend.log`.
- Frontend: `flutter run -d web-server` cổng 3000, bản debug, `API_HOST=http://localhost:8080`.
  Không có flutter trên Windows thì tự chạy qua WSL2. Log: `dev\logs\frontend.log`.
- Mở `http://localhost:3000/login` (công ty) hoặc `http://localhost:3000/admin/login` (system admin).
- DB tạo trước khi gộp baseline (10/2026) báo `Migration checksum mismatch` → chạy `dev\reset-db.cmd` một lần.

---

## 3. Chạy thủ công

### Backend

```bash
cd backend
mvn spring-boot:run                    # hoặc: mvn clean package -DskipTests && java -jar target/bosskin-*.jar
```

Biến môi trường chính (đặt trong `backend/.env`, xem `.env.example`):

| Biến | Ghi chú |
|---|---|
| `DB_URL`, `DB_USERNAME`, `DB_PASSWORD` | Mặc định `jdbc:mysql://localhost:3306/bosskin` |
| `JWT_SECRET` | **Bắt buộc**, ≥ 32 byte; backend từ chối khởi động nếu thiếu |
| `BOOTSTRAP_SYSADMIN_EMAIL`, `BOOTSTRAP_SYSADMIN_PASSWORD` | Tạo system admin đầu tiên khi DB trống |
| `CORS_ALLOWED_ORIGINS` | Mặc định cho phép `localhost:*` |
| `FIREBASE_SERVICE_ACCOUNT_PATH` / `_JSON` | Tuỳ chọn — không có thì tắt thông báo đẩy |

Test backend: `mvn verify` (cần Docker cho Testcontainers MySQL).

### Frontend web

```bash
cd frontend
flutter run -d chrome --dart-define=API_HOST=http://localhost:8080
# hoặc bản build: flutter build web --dart-define=API_HOST=http://localhost:8080 && python serve.py  (cổng 3000)
```

---

## 4. Chạy Flutter trên điện thoại Android (WSL2)

> Mỗi lần mở WSL2 mới đều phải làm lại các bước này.

### Bước 4.1 — Kết nối điện thoại qua USB

Trên điện thoại: bật **USB Debugging** (`Cài đặt → Tùy chọn nhà phát triển → USB Debugging`).

### Bước 4.2 — Forward USB từ Windows vào WSL2

Mở **PowerShell (Admin)** trên Windows:
```powershell
# Xem danh sách USB, tìm tên điện thoại lấy BUSID (ví dụ: 2-3)
usbipd list

# Lần đầu: bind device (chỉ cần 1 lần)
usbipd bind --busid 2-3

# Mỗi lần kết nối: attach vào WSL
usbipd attach --wsl --busid 2-3
```

> Nếu chưa cài usbipd-win: `winget install usbipd`

**Nếu điện thoại không nhận (`unauthorized` hoặc không thấy):**
```powershell
# PowerShell (Admin) — detach rồi attach lại
usbipd detach --busid 5-1
usbipd attach --wsl --busid 5-1
```
Sau đó ngay lập tức chạy trên WSL:
```bash
/home/bk54/Android/Sdk/platform-tools/adb devices
```
- Điện thoại hiện `unauthorized` → bấm **Allow** trên điện thoại
- Không thấy device → kiểm tra USB Debugging đã bật chưa (`Cài đặt → Tùy chọn nhà phát triển → USB Debugging`)

### Bước 4.3 — Khởi động ADB trong WSL2

```bash
sudo /home/bk54/Android/Sdk/platform-tools/adb start-server
/home/bk54/Android/Sdk/platform-tools/adb devices
# Điện thoại phải hiện "device", nếu hiện "unauthorized" → bấm Allow trên điện thoại
```

### Bước 4.4 — Chạy Flutter

```bash
cd frontend
flutter run
```

---

## 5. Build APK Android

### APK đã build sẵn

File APK release mới nhất tại: `frontend/output/app-release.apk` (28MB)  
Cài trực tiếp lên điện thoại — không cần Google Play.

### Build lại APK

```bash
cd frontend
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Copy ra thư mục output
cp build/app/outputs/flutter-apk/app-release.apk output/app-release.apk
```

### Cấu hình server sau khi cài

Sau khi cài APK, app cho phép nhập địa chỉ server tùy ý trong màn hình đăng nhập.  
Nhập URL backend EB, ví dụ: `http://<eb-url>.elasticbeanstalk.com`

---

## 6. Chạy Frontend (Flutter Web)

### Bước 4.1 — Cài dependencies

```bash
cd frontend
flutter pub get
```

### Bước 4.2 — Build

```bash
flutter build web --no-tree-shake-icons
```

### Bước 4.3 — Serve

```bash
python3 serve.py
```

Frontend chạy tại `http://localhost:3000`.

> **Lưu ý:** `serve.py` là SPA-aware server — mọi path không tìm thấy file đều trả về `index.html` (cần thiết cho Flutter Web routing).

---

## 7. Tài khoản mặc định (seed từ migration)

### System Admin — quản lý toàn platform

| | |
|---|---|
| URL | `http://localhost:3000/admin/login` |
| Email | `sysadmin@bosskin.io` |
| Password | `Admin@123` |

### Company User — tài khoản seed sẵn (công ty mẫu)

| Role | Email | Password | Ghi chú |
|---|---|---|---|
| Admin công ty | `admin@bosskin.vn` | `Admin@123` | Toàn quyền trong công ty |
| HR Manager | `hr@bosskin.vn` | `Admin@123` | Quản lý nhân sự |

URL đăng nhập: `http://localhost:3000/login`

> Mật khẩu các tài khoản seed đều là `Admin@123` (BCrypt trong V2, V4 migration).

### Company User (tạo mới)

Sau khi System Admin tạo công ty qua `/admin/dashboard`, email + password admin công ty là do người dùng nhập trong form tạo công ty.

---

## 8. Luồng sử dụng lần đầu

```
1. Đăng nhập System Admin  →  /admin/login
2. Tạo công ty mới         →  Nhập tên công ty + email/password admin công ty
3. Login vào công ty       →  Click icon đăng nhập trên card công ty
   hoặc
   Đăng nhập trực tiếp     →  /login  (dùng email admin công ty vừa tạo)
```

---

## 9. Cấu trúc dự án

```
flutter-bosskin/
├── backend/                  # Spring Boot 3 + Java 17
│   ├── src/main/java/com/bosskin/
│   │   ├── controller/       # REST controllers
│   │   ├── service/          # Business logic
│   │   ├── entity/           # JPA entities
│   │   ├── repository/       # Spring Data repositories
│   │   ├── dto/              # Request/Response DTOs
│   │   └── security/         # JWT + Spring Security config
│   └── src/main/resources/
│       ├── application.yml
│       └── db/migration/     # Flyway SQL migrations
├── frontend/                 # Flutter Web
│   ├── lib/
│   │   ├── core/             # Constants, theme, routes
│   │   ├── data/services/    # AuthService, API calls
│   │   └── presentation/     # Screens & widgets
│   ├── build/web/            # Output sau khi flutter build web
│   └── serve.py              # SPA HTTP server (port 3000)
├── docker-compose.yml        # MySQL + Backend containers
└── README.md
```

---

## 10. API Endpoints chính

| Method | Path | Mô tả |
|---|---|---|
| POST | `/admin/auth/login` | Đăng nhập System Admin |
| GET | `/admin/companies` | Danh sách công ty |
| POST | `/admin/companies` | Tạo công ty mới |
| POST | `/admin/companies/:id/impersonate` | Lấy token login vào công ty |
| PATCH | `/admin/companies/:id/toggle-active` | Bật/tắt công ty |
| POST | `/api/v1/auth/login` | Đăng nhập company user |
| GET | `/api/v1/employees` | Danh sách nhân viên |
| GET | `/api/v1/payroll` | Danh sách bảng lương |
| GET | `/api/v1/attendance` | Dữ liệu chấm công |

---

## 11. Xử lý sự cố thường gặp

**Backend lỗi Flyway checksum mismatch:**
```yaml
# application.yml
spring.flyway.validate-on-migrate: false
```

**Frontend vẫn load file cũ (cache):**
```bash
# Hard refresh trình duyệt
Ctrl + Shift + R  (Windows/Linux)
Cmd + Shift + R   (Mac)
```

**Flutter Web hiển thị `#` trong URL:**  
Đảm bảo `main.dart` có gọi `usePathUrlStrategy()` trước `runApp()`.

**Backend lỗi port 8080 đã dùng:**
```bash
# Tìm và kill process đang dùng port 8080
lsof -ti:8080 | xargs kill -9
```
