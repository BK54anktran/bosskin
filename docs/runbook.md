# BossKin — Runbook vận hành

Tài liệu cho người deploy và trực sự cố. Cập nhật cùng code (quy tắc 2 trong CLAUDE.md): đổi biến môi trường,
cách deploy, health check hay migration thì sửa file này trong cùng commit.

## 1. Thành phần

| Thành phần | Dịch vụ | Ghi chú |
|---|---|---|
| Backend | Elastic Beanstalk, nền tảng Java SE (Corretto 17) | Gói deploy: `bosskin-1.0.0.jar` + `Procfile` + `.ebextensions/` |
| CSDL | RDS MySQL 8 | Flyway tự chạy migration khi app khởi động (`V1`…`V9`, chỉ tiến) |
| File | S3 | Ảnh đại diện, tài liệu, lịch sử Excel |
| Thông báo đẩy | Firebase Cloud Messaging | Khoá service account qua biến môi trường |
| Web / app | Flutter | Build với `--dart-define=API_HOST=https://api.<tên-miền>` |

## 2. Biến môi trường (Environment properties trên EB, giá trị bí mật để trong SSM)

| Biến | Bắt buộc | Ví dụ / ghi chú |
|---|---|---|
| `DB_URL` | ✔ | `jdbc:mysql://<rds-endpoint>:3306/bosskin?sslMode=REQUIRED&serverTimezone=Asia/Ho_Chi_Minh` |
| `DB_USERNAME`, `DB_PASSWORD` | ✔ | Tài khoản riêng cho app, không dùng master |
| `JWT_SECRET` | ✔ | ≥ 32 byte ngẫu nhiên: `openssl rand -base64 48`. Thiếu → app không khởi động |
| `CORS_ALLOWED_ORIGINS` | ✔ (bản web) | `https://app.<tên-miền>,https://<tên-miền trang giới thiệu>` (nhiều giá trị cách dấu phẩy; trang giới thiệu gửi form dùng thử vào API) |
| `TRIAL_MAX_PER_IP_HOUR` | Không | Số yêu cầu dùng thử tối đa mỗi IP mỗi giờ, mặc định 5 |
| `SUPABASE_URL`, `SUPABASE_SECRET_KEY` | Không | Đặt cả hai → yêu cầu dùng thử đọc/ghi bảng `trial_requests` trên Supabase (nguồn chung với trang Netlify). Khoá bí mật lấy ở Supabase → Project Settings → API Keys (`sb_secret_…`), chỉ để ở biến môi trường |
| `BOOTSTRAP_SYSADMIN_EMAIL`, `BOOTSTRAP_SYSADMIN_PASSWORD` | Lần đầu | Chỉ dùng khi DB chưa có system admin. Xoá sau khi đăng nhập được |
| `BOOTSTRAP_ADD_SYSADMIN_EMAIL`, `BOOTSTRAP_ADD_SYSADMIN_PASSWORD` | Không | Thêm một system admin lúc khởi động nếu email chưa có (không sửa tài khoản đang có). Dùng khi không vào được /admin; xoá sau khi đăng nhập được |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Nên có | Nội dung JSON hoặc base64. Không đặt → tắt push |
| `AWS_S3_BUCKET`, `AWS_REGION` | Nên có | Trên EB dùng IAM role của instance, không cần `AWS_ACCESS_KEY` |
| `DOCUMENTS_STORAGE`, `DOCUMENTS_LOCAL_DIR`, `DOCUMENTS_LINK_TTL_SECONDS` | Không | Tài liệu nhân sự (bước N): `s3` / `local`, trống = `s3` khi có bucket. Object trên S3 không công khai, chỉ cấp presigned GET (mặc định 300 giây). Bản web tải file qua presigned URL nên bucket cần CORS cho phép `GET` từ origin của app. `local` chỉ dùng cho dev (mặc định `~/.bosskin/documents`) |
| `REQUIRE_SYSADMIN_2FA` | Không | Mặc định `true`: system admin phải cài 2FA ở lần đăng nhập đầu. Chỉ đặt `false` khi khẩn cấp (mục 11) |
| `JWT_EXPIRATION_MS` | Không | Mặc định 1800000 (30 phút) |
| `LOG_LEVEL_APP` | Không | Mặc định `INFO` ở prod |
| `DB_POOL_SIZE` | Không | Mặc định 10 |
| `PORT` | Không | Đặt sẵn 5000 trong `.ebextensions` |

## 3. Deploy

1. Push code lên `main` → workflow **Backend tests** chạy toàn bộ test (Testcontainers). Phải xanh.
2. Nếu bản này có migration mới (`backend/src/main/resources/db/migration/V*.sql` khác bản đang chạy):
   **tạo snapshot RDS thủ công** trước (mục 5) và ghi tên snapshot vào ghi chú phát hành.
3. GitHub → Actions → **Deploy to Elastic Beanstalk** → *Run workflow* (nhánh `main`).
   Workflow chạy lại test, đóng gói và deploy với nhãn phiên bản = mã commit.
4. Kiểm tra sau deploy (≤ 5 phút):
   - `curl https://api.<tên-miền>/actuator/health` → `{"status":"UP"}`
   - EB console: Health = Ok, không có instance Degraded.
   - Đăng nhập bản web bằng một tài khoản thử, mở Chấm công và Bảng lương.
   - Log EB không có `ERROR` mới (tìm theo mã request nếu có lỗi).

## 4. Rollback

- **Chỉ đổi code, không có migration mới:** EB console → Application versions → chọn nhãn (mã commit) trước đó → Deploy.
- **Có migration mới:** Flyway chỉ chạy tiến, bản cũ có thể không chạy được trên schema mới.
  1. Ưu tiên sửa tiến: viết migration `V{n+1}` sửa lỗi rồi deploy lại.
  2. Nếu dữ liệu hỏng: khôi phục snapshot đã tạo ở bước 3.2 thành instance mới (mục 5), đổi `DB_URL` sang instance đó,
     rồi deploy lại phiên bản cũ. Dữ liệu phát sinh sau thời điểm snapshot sẽ mất — báo người dùng nhập lại.
- Sau rollback: ghi lại nguyên nhân, mã request lỗi, thời điểm vào nhật ký sự cố.

## 5. Sao lưu và khôi phục DB

- **Tự động:** RDS automated backup, giữ 14 ngày, có point-in-time recovery (PITR).
- **Thủ công:** trước mỗi deploy có migration, và trước khi khoá kỳ lương: RDS → Snapshots → Take snapshot,
  đặt tên `bosskin-<yyyymmdd>-<lý do>`.
- **Khôi phục:** RDS → Restore to point in time (hoặc Restore snapshot) → **luôn ra instance mới**, không ghi đè
  instance đang chạy → kiểm tra dữ liệu → đổi `DB_URL` trên EB → EB tự khởi động lại app.
- **Bản xuất ra ngoài AWS (hằng tuần):**
  ```bash
  mysqldump --single-transaction --routines --set-gtid-purged=OFF \
    -h <rds-endpoint> -u <user> -p bosskin | gzip > bosskin-$(date +%F).sql.gz
  ```
  Khôi phục thử mỗi tháng một lần vào DB tạm (`gunzip -c … | mysql -h … bosskin_restore_test`) để chắc bản sao lưu dùng được.
- Không bao giờ chạy `flyway clean` hay xoá bảng trên prod (`spring.flyway.clean-disabled` luôn bật ở prod).

## 6. Theo dõi và tra lỗi

- **Health:** `GET /actuator/health` (mở công khai, không lộ chi tiết). Có thêm `/actuator/health/liveness` và
  `/actuator/health/readiness`. Các endpoint actuator khác bị chặn.
- **Mã request:** mỗi response có header `X-Request-ID`; body lỗi có `requestId`. Mọi dòng log có `[mã]` ngay sau mức log.
  Người dùng báo lỗi → hỏi mã request (hoặc giờ + tài khoản) → tìm trong log EB (`eb logs` hoặc CloudWatch).
- **Nhật ký thao tác:** bảng `audit_logs`, xem trên app (menu *Nhật ký thao tác*, quyền `AUDIT_VIEW`) hoặc
  `GET /admin/audit-logs` (system admin). Ghi: duyệt/sửa/xoá công, nhập công từ Excel, duyệt đơn sửa giờ,
  khoá/mở kỳ, tạo/sửa/duyệt/trả/xoá lương, đổi vai trò và quyền, khoá tài khoản, gỡ thiết bị, impersonate,
  tạo/sửa công ty. Chỉ ghi thêm, không có API sửa/xoá.

## 7. Sự cố thường gặp

| Hiện tượng | Nguyên nhân hay gặp | Cách xử lý |
|---|---|---|
| Health `DOWN`, EB Degraded | App không kết nối được DB | Kiểm `DB_URL`, security group RDS cho phép EB, RDS còn chạy |
| App không khởi động, log `Thiếu JWT_SECRET` | Chưa đặt hoặc quá ngắn | Đặt `JWT_SECRET` ≥ 32 byte |
| Log `Validate failed: Migrations have failed validation` | Migration đã chạy bị sửa sau khi deploy | Không sửa file migration cũ; trả file về như cũ, thêm migration mới |
| Bản web báo lỗi CORS | Thiếu origin | Thêm vào `CORS_ALLOWED_ORIGINS` |
| Không nhận thông báo đẩy | Thiếu/sai khoá Firebase | Đặt `FIREBASE_SERVICE_ACCOUNT_JSON`, xem log `FcmConfig` |
| Người dùng bị đăng xuất liên tục | Đồng hồ máy chủ lệch, hoặc `JWT_SECRET` đổi giữa các instance | Đồng bộ thời gian; mọi instance cùng một secret |

## 8. Lần đầu dựng môi trường mới

Trên AWS: dựng bằng stack CloudFormation `infra/aws/bosskin.yaml` (EB + RDS + S3 + IAM + Secrets Manager + cảnh báo),
hướng dẫn từng bước ở `infra/aws/README.md`; stack đặt sẵn các biến mục 2 và tạo DB trống, nên bỏ qua bước 1–2 dưới đây.
Nhập dữ liệu công ty thật: `docs/chuyen-du-lieu.md`. Thử trên điện thoại trước khi phát app: `docs/thu-dien-thoai.md`.

1. Tạo DB trống `bosskin` (utf8mb4) và user cho app.
2. Đặt biến môi trường mục 2, kèm `BOOTSTRAP_SYSADMIN_*`.
3. Chạy workflow deploy. Flyway tạo toàn bộ schema từ `V1`.
4. Đăng nhập `/admin` bằng system admin — lần đầu phải quét QR cài 2FA và cất mã dự phòng — rồi tạo công ty đầu tiên. Admin công ty phải đổi mật khẩu ở lần đăng nhập đầu.
5. Xoá `BOOTSTRAP_SYSADMIN_PASSWORD` khỏi biến môi trường.

## 9. Môi trường dev (máy chủ dự án)

Xem CLAUDE.md, mục *Chạy & quản lý server dev*: `dev\runner.cmd`, `dev\start.cmd`, seed công ty mẫu `dev\seed-th.cmd`.

## 10. Phát hành web và app Android (Bước B)

Workflow **Frontend build** (`.github/workflows/frontend-build.yml`) chạy cho mỗi push đụng `frontend/**`
(hoặc chạy tay): `flutter analyze` (lỗi mới chặn), kiểm tra chuỗi tiếng Việt viết cứng, build web và APK.
Kết quả tải ở GitHub → Actions → lần chạy → *Artifacts*: `bosskin-web-<số>` và `bosskin-apk-<số>`.
Số build = số lần chạy workflow (versionCode luôn tăng, cài đè được lên bản cũ).

**Biến repo** (Settings → Secrets and variables → Actions → *Variables*):
`API_HOST` = địa chỉ backend mà bản web/app gọi, vd. `https://api.<tên-miền>`.

**Khoá ký APK — chủ dự án tự tạo một lần, giữ suốt đời app.** Mất khoá hoặc mật khẩu thì không phát hành
được bản cập nhật cho máy đã cài (phải gỡ app, cài lại).

1. Tạo khoá (máy có JDK; trên Windows dùng `keytool` trong thư mục JDK `bin`):
   ```
   keytool -genkeypair -v -keystore bosskin-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias bosskin
   ```
   Nhập mật khẩu kho khoá, thông tin đơn vị; mật khẩu khoá có thể trùng mật khẩu kho.
2. Lấy nội dung base64 của file (PowerShell):
   ```
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("bosskin-release.jks")) | Set-Clipboard
   ```
3. GitHub → Settings → Secrets and variables → Actions → *New repository secret*:
   `ANDROID_KEYSTORE_BASE64` (dán nội dung bước 2), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (= `bosskin`),
   `ANDROID_KEY_PASSWORD`.
4. Cất file `.jks` + hai mật khẩu ở **hai nơi an toàn** (trình quản lý mật khẩu + bản sao ngoại tuyến).
   **Không** đưa file vào git (đã chặn trong `frontend/android/.gitignore`).

Chưa có secrets → APK vẫn build nhưng ký bằng khoá debug (chỉ để thử nội bộ, workflow báo cảnh báo).
Build máy cá nhân: tạo `frontend/android/key.properties` (`storeFile=`, `storePassword=`, `keyAlias=`, `keyPassword=`)
rồi `flutter build apk --release --dart-define=API_HOST=...`.

## 11. Xác thực 2 lớp (2FA, Bước C)

- **System admin**: luôn bắt buộc. Lần đăng nhập đầu hiện mã QR → quét bằng Google/Microsoft Authenticator → nhập mã → nhận 8 mã dự phòng (mỗi mã dùng 1 lần, chỉ hiện một lần).
- **Admin công ty**: tự bật trong Hồ sơ. System admin có thể bắt buộc theo công ty (nút khiên trên thẻ công ty ở `/admin`):
  người có quyền `ROLE_MANAGE` chưa cài sẽ phải cài ở lần đăng nhập tới và không tự tắt được.
- **Nhân viên mất điện thoại**: đăng nhập bằng một mã dự phòng, hoặc người có quyền `USER_MANAGE` gỡ 2FA ở Phân quyền → Người dùng (biểu tượng khoá cạnh công tắc). Ghi nhật ký `2FA_RESET`.
- **Thêm / khoá system admin**: `/admin` → tab "Quản trị viên". Mật khẩu sinh tự động, chỉ hiện một lần — gửi riêng cho người đó;
  họ phải cài 2FA ở lần đăng nhập đầu. Một admin mất điện thoại: admin khác gỡ 2FA cho họ ở tab này.
- **System admin mất điện thoại và hết mã dự phòng, và không còn admin nào khác**: tạm đặt `REQUIRE_SYSADMIN_2FA=false` không giúp được vì tài khoản đã bật 2FA.
  Cách nhanh: đặt `BOOTSTRAP_ADD_SYSADMIN_EMAIL/PASSWORD` cho một email mới, khởi động lại, đăng nhập rồi gỡ 2FA tài khoản cũ ở tab "Quản trị viên".
  Hoặc gỡ trực tiếp trong DB (cần người có quyền DB, ghi lại lý do):
  `UPDATE system_admins SET totp_enabled=0, totp_secret=NULL, totp_recovery_codes=NULL WHERE email='<email>';`
  rồi đăng nhập lại và cài 2FA mới.
- Đồng hồ máy chủ phải đúng (NTP): mã chấp nhận lệch ±30 giây.
- Seed dev (`dev\seed-th.cmd`): script tự cài 2FA cho system admin ở lần đầu, ghi khoá vào `backend\.env` (`SEED_SYSADMIN_TOTP_SECRET`)
  và in khoá/mã dự phòng để thêm vào app xác thực.

## 12. Trang giới thiệu và yêu cầu dùng thử

- Nguồn dữ liệu chung: Supabase project `bosskin`, bảng `trial_requests` (`landing/supabase/*.sql`). Trang Netlify ghi thẳng vào đó
  (khoá công khai, chỉ được thêm); app BossKin đọc/xử lý ở `/admin` → tab "Yêu cầu dùng thử" qua `SUPABASE_URL` + `SUPABASE_SECRET_KEY`.
  Thiếu hai biến này thì backend dùng bảng MySQL `trial_requests` (V12) như trước.
- Chống spam: trigger trên Supabase (chuẩn hoá số điện thoại, trùng số 10 phút bỏ qua, ≤ 5 lượt/IP/giờ); API của BossKin còn giới hạn theo IP
  (`TRIAL_MAX_PER_IP_HOUR`).
- Supabase không gọi được (sai khoá, mất mạng) → tab báo `error.trial.store_unavailable`; dữ liệu vẫn nằm trên Supabase, xem tạm ở Dashboard.
- Đây là dữ liệu cá nhân của khách: chỉ system admin xem; form có ô đồng ý liên hệ. Không đưa khoá bí mật vào trang hay vào git.

## 13. Thông số thuế TNCN và bảo hiểm (bước I)

- Bảng `tax_policies` (V13) giữ giảm trừ bản thân / người phụ thuộc, biểu thuế lũy tiến, mức tham chiếu (trần BHXH/BHYT = hệ số × mức
  tham chiếu) và lương tối thiểu 4 vùng (trần BHTN = hệ số × lương tối thiểu vùng). Dùng chung mọi công ty; mỗi công ty chọn vùng ở
  Cài đặt công ty → Lương.
- Kỳ lương dùng chính sách có ngày hiệu lực gần nhất **trước hoặc bằng ngày cuối kỳ**. Phiếu đã duyệt / đã trả không đổi; phiếu nháp
  đổi khi bấm Tính lại.
- Khi luật đổi (lương cơ sở, lương tối thiểu vùng, mức giảm trừ, biểu thuế): system admin vào /admin → tab "Thuế & BH" → "Thêm chính
  sách" với ngày hiệu lực mới (form điền sẵn từ chính sách gần nhất), ghi căn cứ pháp lý vào ô ghi chú. Không sửa chính sách cũ đã dùng
  cho kỳ đã chốt. Mọi thao tác ghi nhật ký `TAX_POLICY_CREATE/UPDATE/DELETE`.
- Dữ liệu có sẵn khi migrate: 01/07/2024 (11 triệu / 4,4 triệu, 7 bậc, mức tham chiếu 2.340.000), 01/01/2026 (15,5 / 6,2 triệu, 5 bậc,
  lương tối thiểu vùng NĐ 293/2025), 01/07/2026 (mức tham chiếu 2.530.000). Đối chiếu văn bản gốc trước khi chạy lương thật.
- Không có chính sách nào hiệu lực cho kỳ → tạo lương báo `error.tax_policy.not_found`.
