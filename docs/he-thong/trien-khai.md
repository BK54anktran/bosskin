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
| Test backend | `cd backend && ./mvnw test` · CI `test.yml` mỗi lần push |
| Đóng gói backend | `./mvnw -DskipTests package` → `target/*.jar` |
| Deploy backend | GitHub Actions **Deploy to Elastic Beanstalk** (`deploy.yml`, chạy tay), nhãn phiên bản = mã commit |
| Build web | `flutter build web --release --dart-define=API_HOST=…` · CI `frontend-build.yml` |
| App Android | runbook mục 10 |
| Kiểm hạ tầng | `cfn-lint infra/aws/bosskin.yaml` · CI `infra-lint.yml` |
| Trang trợ giúp | `python3 help/tools/build_help.py` → `help/*.html`, host tĩnh bất kỳ ([help/README.md](../../help/README.md)) |
| Tài liệu tự sinh | `python3 tools/docs/gen_he_thong.py [--check]` |

Migration: thêm `V<n>__mo_ta.sql`, không sửa file đã chạy. Flyway tự chạy khi app khởi động (`validate-on-migrate`, cấm `clean` ở prod).
Bản có migration mới → **snapshot RDS trước khi deploy** (runbook mục 3–4: rollback = sửa tiến hoặc khôi phục snapshot).

## Vận hành hằng ngày

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
