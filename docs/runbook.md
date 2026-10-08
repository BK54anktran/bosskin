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
| `CORS_ALLOWED_ORIGINS` | ✔ (bản web) | `https://app.<tên-miền>` (nhiều giá trị cách dấu phẩy) |
| `BOOTSTRAP_SYSADMIN_EMAIL`, `BOOTSTRAP_SYSADMIN_PASSWORD` | Lần đầu | Chỉ dùng khi DB chưa có system admin. Xoá sau khi đăng nhập được |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Nên có | Nội dung JSON hoặc base64. Không đặt → tắt push |
| `AWS_S3_BUCKET`, `AWS_REGION` | Nên có | Trên EB dùng IAM role của instance, không cần `AWS_ACCESS_KEY` |
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

1. Tạo DB trống `bosskin` (utf8mb4) và user cho app.
2. Đặt biến môi trường mục 2, kèm `BOOTSTRAP_SYSADMIN_*`.
3. Chạy workflow deploy. Flyway tạo toàn bộ schema từ `V1`.
4. Đăng nhập `/admin` bằng system admin, tạo công ty đầu tiên. Admin công ty phải đổi mật khẩu ở lần đăng nhập đầu.
5. Xoá `BOOTSTRAP_SYSADMIN_PASSWORD` khỏi biến môi trường.

## 9. Môi trường dev (máy chủ dự án)

Xem CLAUDE.md, mục *Chạy & quản lý server dev*: `dev\runner.cmd`, `dev\start.cmd`, seed công ty mẫu `dev\seed-th.cmd`.
