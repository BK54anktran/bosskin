# Bosskin — Claude Context

## Quy tắc làm việc (chủ dự án đặt — luôn áp dụng)

1. **Môi trường dev — toàn quyền.** Được tự commit, gộp và **push lên `main`** mà không cần hỏi.
   Database local (dev) được toàn quyền tạo / sửa / xoá dữ liệu và schema.
   Commit đứng tên `bk54anktran <ankankbk54@gmail.com>`, **không** thêm chữ ký Claude
   (`Co-Authored-By`, `Claude-Session`...). Production (khi có) vẫn phải hỏi trước.
   Push từ thư mục repo trên máy chủ dự án (D:\bosskin): git ở đó đã có token qua
   `credential.helper store --file=.git/.git-credentials` (file trong `.git`, không commit).
2. **Tài liệu – design – code – database luôn đi cùng nhau.** Sửa một trong bốn mà ảnh hưởng
   đến cái khác thì **bắt buộc** sửa theo trong cùng đợt:
   - code đổi API/nghiệp vụ → cập nhật `docs/` (kế hoạch, đánh giá, tài liệu hệ thống);
   - đổi schema → migration Flyway mới + entity/DTO + tài liệu;
   - đổi giao diện/luồng → cập nhật design và chuỗi l10n;
   - tiến độ kế hoạch → cập nhật `docs/review-2026-10/ke-hoach.html` (và bản artifact).
3. **KHÔNG BAO GIỜ tự xoá / reset dữ liệu** (kể cả DB dev): không chạy `dev\reset-db.cmd`, không DROP/TRUNCATE,
   không Flyway clean nếu chủ dự án chưa đồng ý rõ ràng trong lần đó. Migration mới chỉ cần khởi động lại backend
   (Flyway tự chạy phần thêm). Cần dữ liệu mẫu mới → thêm bằng API/script bổ sung, không xoá cái cũ.
4. **Ưu tiên dòng lệnh, không dùng điều khiển màn hình** khi có cách chạy bằng lệnh: server dev chạy qua
   `dev\runner.cmd` (xem mục "Chạy & quản lý server dev"). Chỉ dùng điều khiển máy tính khi runner chưa bật.
5. **Giới hạn sử dụng.** Mỗi đợt làm việc, kiểm tra thời điểm reset hạn mức tiếp theo.
   Khi mức dùng chạm ~99%: dừng, commit/push phần đã xong, tổng hợp tiến độ, và hẹn lịch
   tiếp tục đúng giờ reset (được tạo phiên mới nếu cần).

## Chạy & quản lý server dev (khi chủ dự án yêu cầu)
- Script ở `dev/` (Windows PowerShell): `dev\start.cmd [backend|frontend]`, `dev\status.cmd`, `dev\stop.cmd [-Force]`,
  `dev\reset-db.cmd` (xoá sạch DB dev, migrate lại, tạo system admin từ `BOOTSTRAP_SYSADMIN_*` trong `backend/.env`),
  `dev\seed-th.cmd` (công ty mẫu "TH company": 4 phòng ban, 8 NV có tài khoản, 4 vai trò, 7 ca gồm ca đêm, ca gãy và
  ca linh hoạt, phân ca 9–10/2026, mẫu xoay ca + phân ca xoay tháng 11 cho 2 công nhân, 4 loại phép, công đã duyệt
  01/09–07/10, đơn chờ duyệt (sửa giờ, nghỉ phép, đổi ca), bảng lương nháp tháng 9; log `dev/logs/seed-th.log`).
  Sửa nghiệp vụ/API mà seed hỏng → sửa `dev/seed-th.ps1` cùng lúc (quy tắc 2).
- Cách chạy: chủ dự án bật `dev\runner.cmd` một lần (để cửa sổ mở). Claude ghi tên lệnh vào
  `dev/run/requests/<id>.req` (start, start-backend, start-frontend, stop, stop-backend, stop-frontend,
  restart-backend, restart-frontend, status, seed-th, start-landing, stop-landing — hai lệnh landing cần bật lại runner
  mới có; `start` đã gồm trang giới thiệu), đọc kết quả ở `dev/run/results/<id>.txt` và log ở `dev/logs/`.
  Runner còn sống nếu `dev/run/runner.alive` được cập nhật trong vài giây. Runner KHÔNG có lệnh reset-db.
- Runner chưa bật: nhờ chủ dự án bật; chỉ khi họ đồng ý mới dùng điều khiển máy tính (double-click `.cmd` trong File Explorer).
  Kiểm tra trang bằng built-in browser (`http://localhost:3000`).
  Backend cổng 8080 (đọc `backend/.env`, cần MySQL localhost:3306), frontend web debug cổng 3000.
- Claude khởi động bằng cách chạy `dev\start.cmd` trên máy Windows của chủ dự án (điều khiển máy tính),
  theo dõi qua `dev/logs/*.log` (đọc được từ thư mục repo), báo URL khi sẵn sàng, tự xử lý lỗi khởi động
  (đọc log → sửa code/config → khởi động lại), và dừng bằng `dev\stop.cmd` khi xong hoặc khi được yêu cầu.
- Trước khi khởi động lại sau khi sửa code backend: `dev\stop.cmd backend` rồi `dev\start.cmd backend`.
  Frontend chạy nền nên không có hot reload: sửa Dart xong thì `dev\stop.cmd frontend` rồi `dev\start.cmd frontend`.

## Stack
- **Frontend**: Flutter (Dart) — Riverpod + GoRouter + Dio
- **Backend**: Spring Boot 3.3 + Java 17 — JPA + JWT + Flyway + MySQL 8.0
- **Infra**: Docker Compose (`docker-compose.yml` ở root)

## Cấu trúc thư mục
```
frontend/lib/
  data/models/              # Dart model classes (fromJson)
  data/repositories/        # Dio HTTP calls
  core/utils/               # Hàm dùng chung (format, error, dialog, ...)
  presentation/
    widgets/                # Shared widgets dùng lại nhiều màn hình
    screens/                # UI screens theo module
backend/src/main/java/com/bosskin/
  entity/                   # JPA entities (kế thừa BaseEntity)
  dto/                      # Request/Response DTOs
  service/                  # Business logic
  controller/               # REST controllers (@RequestMapping /api/v1/...)
  repository/               # Spring Data JPA repos
  security/                 # JWT + UserDetails
backend/src/main/resources/db/migration/
  V{n}__description.sql     # Flyway migrations — luôn tăng số version
frontend/lib/l10n/
  app_vi.arb                # Chuỗi tiếng Việt
  app_en.arb                # Chuỗi tiếng Anh
```

## Auth & Roles
- JWT Bearer token
- Roles (thứ tự quyền): `ADMIN > HR_MANAGER > HR_STAFF > EMPLOYEE`
- Controller dùng `@AuthenticationPrincipal User user` để lấy user hiện tại
- 2FA (TOTP, V11): `core/Totp`, `service/TwoFactorService`. Login trả `twoFactor` = `REQUIRED` | `SETUP_REQUIRED` + `challengeToken`
  (JWT type `2FA`, 5 phút) thay cho access token → `/api/v1/auth/2fa/{verify,setup,enable}` (system admin: `/admin/auth/2fa/...`).
  System admin luôn bắt buộc (`REQUIRE_SYSADMIN_2FA`, test tắt); admin công ty tuỳ chọn, system admin bật buộc theo công ty
  (`companies.require_admin_2fa`, áp cho user có `ROLE_MANAGE`). FE: `TwoFactorChallenge` → `TwoFactorScreen`; Hồ sơ có `TwoFactorCard`;
  gỡ 2FA cho NV ở tab Người dùng (`DELETE /users/{id}/2fa`, không hiện nút cho chính mình — tự tắt ở Hồ sơ).
  Tài khoản không gắn nhân viên (admin công ty): Hồ sơ chỉ hiện phần Tài khoản (2FA + đổi mật khẩu), không gọi `/profile`.
- Quản lý system admin: `/admin/system-admins` (danh sách, tạo — mật khẩu 16 ký tự sinh tự động trả một lần, khoá/mở,
  đặt lại mật khẩu, gỡ 2FA; không thao tác lên chính mình, luôn còn ≥ 1 admin hoạt động; nhật ký `SYSADMIN_*`).
  FE tab "Quản trị viên" (`screens/admin/system_admins_tab.dart`).

---

## Quy tắc bắt buộc — Frontend

### 1. Component & Widget
- **Bắt buộc dùng lại** shared widget có sẵn trong `presentation/widgets/` trước khi tự viết:
  - `PermissionGuard` — ẩn/hiện theo quyền
  - `AppDropdown` — dropdown chuẩn
  - `SearchTextField` — ô tìm kiếm
  - `PaginationBar` — phân trang
  - `StatusBadge` — chip trạng thái
  - `EmptyState` — màn hình rỗng
  - `DepartmentPickerField` — chọn phòng ban
- Nếu logic UI lặp lại ≥ 2 màn hình → tách thành widget mới trong `presentation/widgets/`
- Không viết widget local bên trong file screen nếu widget đó có thể tái sử dụng

### 2. Hàm dùng chung
- Format tiền, ngày, giờ, số → đặt trong `core/utils/`
- Các utils hiện có: `error_utils.dart`, `dialog_utils.dart`, `text_utils.dart`, `attendance_message_utils.dart`
- Không copy-paste cùng một hàm vào nhiều file — tạo util mới nếu chưa có

### 3. Đa ngôn ngữ — BẮT BUỘC
- **Mọi chuỗi hiển thị cho user đều phải qua l10n**, không được hardcode text trong widget
- Khi thêm text mới: thêm vào **cả hai file** `app_vi.arb` và `app_en.arb`
- Dùng `AppLocalizations.of(context)!` (biến `s`) để lấy chuỗi
- Key đặt theo `camelCase`, mô tả rõ ngữ cảnh, ví dụ: `payrollBaseSalaryPerDay`, `leaveRequestApprove`
- Không dùng `Text('Lương cơ bản')` trực tiếp — phải là `Text(s.baseSalary)`

### 4. Phân quyền màn hình mới
Mỗi màn hình/tính năng mới **bắt buộc** có hệ thống quyền đầy đủ:

**Nguyên tắc phụ thuộc quyền:**
- `VIEW` là điều kiện tiên quyết của mọi quyền khác (EDIT, APPROVE, DELETE đều cần VIEW trước)
- Khi check quyền EDIT/APPROVE: luôn check `VIEW` trước, sau đó check quyền hành động

**Các loại quyền theo tính năng** (ví dụ module `payroll`):
```
payroll.view        — xem danh sách / chi tiết
payroll.edit        — tạo mới / chỉnh sửa
payroll.approve     — duyệt
payroll.delete      — xóa
```

**Scope dữ liệu** — scope luôn đi kèm với quyền `view`, các quyền khác kế thừa scope của view:
- `ALL` — toàn bộ công ty
- `MY_DEPARTMENT` — chỉ phòng ban của mình
- `MY_DEPARTMENT_AND_BELOW` — phòng ban mình và phòng ban cấp dưới
- `ONLY_ME` — chỉ bản thân
- `PICK` — chọn cụ thể từng phòng ban (dùng `roleViewDepartment` trong Role entity)

**Triển khai trên Frontend:**
- Bọc UI bằng `PermissionGuard(permission: 'payroll.edit', child: ...)` để ẩn button/action
- Không chỉ ẩn UI — repository cũng không được gọi API nếu không có quyền
- Scope lấy từ `user.role.roleViewAllCompany` và `user.role.roleViewDepartmentId`

---

## Quy tắc bắt buộc — Backend

### 1. DB Migration
- `V1__baseline.sql` là schema gộp từ V1–V117 cũ (10/2026, trước go-live). DB tạo trước baseline phải xoá và tạo lại.
- Không seed tài khoản trong migration. System admin đầu tiên tạo qua `BOOTSTRAP_SYSADMIN_EMAIL` / `BOOTSTRAP_SYSADMIN_PASSWORD`.
  Thêm system admin khi chưa vào được /admin: `BOOTSTRAP_ADD_SYSADMIN_EMAIL` / `_PASSWORD` (tạo lúc khởi động nếu email chưa có).
- Unique trên bảng có xoá mềm dùng cột sinh `*_key` (NULL khi đã xoá), xem cuối `V1__baseline.sql`.
- Mỗi thay đổi schema **bắt buộc** có file Flyway mới (`V{n+1}__...sql`)
- Kiểm tra version hiện tại: `ls db/migration/ | sort -t'V' -k2 -n | tail -3`
- Entity dùng Lombok (`@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor`)
- DTO tách rõ `Response` (read) và `Upsert`/`Request` (write)
- Validation dùng `@NotNull`, `@Valid` trên DTO

**Quy tắc clean schema — BẮT BUỘC:**
- Đổi tên cột → migration phải `DROP COLUMN` cột cũ, `ADD COLUMN` cột mới (hoặc `CHANGE`/`RENAME COLUMN`), **không** giữ cột cũ
- Thay thế cột bằng cột khác → `DROP COLUMN` cột cũ trong cùng migration
- Bảng cũ không còn dùng → `DROP TABLE` trong migration tiếp theo
- Không để lại "cột rác" hay "bảng rác" không có entity/code nào dùng
- Nếu rename để backward-compat tạm thời → phải có comment `-- TODO: drop after deploy` và tạo migration drop ngay sau

### 2. Phân quyền API — BẮT BUỘC
- **Mọi API endpoint đều phải kiểm tra quyền** — không có endpoint nào bỏ qua
- Dùng `user.can("module.action")` hoặc `@PreAuthorize` để guard
- Service phải lọc dữ liệu theo scope của user:
  - `roleViewAllCompany = true` → trả về toàn bộ công ty
  - `roleViewAllCompany = false` + `roleViewDepartment != null` → lọc theo phòng ban đó
  - Các scope khác xử lý tương tự
- Quy tắc phụ thuộc quyền giống Frontend: EDIT/APPROVE/DELETE đều cần VIEW trước

### 3. Đa ngôn ngữ — BẮT BUỘC
- **Backend không được trả về message text trực tiếp** — chỉ trả về **key**
- Ví dụ đúng: `throw new ResponseStatusException(HttpStatus.FORBIDDEN, "error.permission.denied")`
- Ví dụ sai: `throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Bạn không có quyền thực hiện")`
- Key lỗi đặt theo format `error.module.reason`, ví dụ:
  - `error.permission.denied`
  - `error.payroll.already_generated`
  - `error.employee.not_found`
- Frontend dịch mã lỗi trong `frontend/lib/core/utils/error_utils.dart` (`_viMessages` / `_enMessages`);
  thêm mã lỗi mới ở backend → thêm bản dịch vi + en ở đó (quy tắc 2). Backend không dịch (đã bỏ MessageTranslator).
- Mã lỗi có tham số: `"error.import.email_in_use|" + email` → bản dịch dùng `{0}`, `{1}`…
  Không nối tham số bằng `:`. Lỗi từng dòng import: `RowResult.error/warn` tự bỏ tiền tố `400 BAD_REQUEST "…"` của
  `e.getMessage()`; hộp xem trước import dịch qua `serverKeyMsg`.
- Không viết chuỗi tiếng Việt cứng trong `.dart` (ngoài l10n/error_utils): CI `tools/ci/check_vi_literals.py`
  chặn chuỗi mới; baseline `tools/ci/vi_literals_baseline.json` (giảm thì chạy `--update`).

### 4. Cấu trúc Service
- Service throw `ResponseStatusException` với **error key**, không phải message text
- Business logic lọc theo scope nằm trong Service, không nằm trong Controller
- Controller chỉ nhận request, delegate vào Service, trả về DTO

---

---

## Quy tắc đặt tên — Frontend (Dart/Flutter)

### Files
| Loại | Convention | Ví dụ |
|------|-----------|-------|
| Screen | `snake_case_screen.dart` | `payroll_screen.dart` |
| Widget dùng chung | `snake_case_widget.dart` hoặc tên mô tả | `status_badge.dart`, `pagination_bar.dart` |
| Model | `snake_case.dart` | `payroll.dart`, `work_shift.dart` |
| Repository | `snake_case_repository.dart` | `employee_repository.dart` |
| Service | `snake_case_service.dart` | `auth_service.dart` |
| Utils | `snake_case_utils.dart` | `error_utils.dart`, `text_utils.dart` |

### Classes & Widgets
| Loại | Convention | Ví dụ |
|------|-----------|-------|
| Widget/Screen public | `PascalCase` | `PayrollScreen`, `StatusBadge` |
| Widget private (local) | `_PascalCase` | `_PayslipDialog`, `_InfoTile` |
| State class | `_PascalCaseState` | `_PayrollScreenState` |
| Model | `PascalCase` | `Payroll`, `WorkShift` |
| Enum | `PascalCase`, values `camelCase` | `PayrollStatus { draft, approved, paid }` |
| Repository/Service | `PascalCase + suffix` | `EmployeeRepository`, `AuthService` |

### Variables & Methods
| Loại | Convention | Ví dụ |
|------|-----------|-------|
| Variable, field | `camelCase` | `baseSalary`, `presentDays` |
| Private state field | `_camelCase` | `_loading`, `_employees`, `_searchCtrl` |
| Constant | `camelCase` (Dart) | `const defaultWorkDays = 22` |
| TextEditingController | `_xCtrl` | `_searchCtrl`, `_hoursPerDayCtrl` |
| Load data method | `_load()` hoặc `_loadX()` | `_load()`, `_loadDepts()` |
| Submit/save method | `_save()`, `_submit()` | `_save()`, `_submitRequest()` |
| Handler method | `_onX` hoặc `_handleX` | `_onApprove()`, `_handleDelete()` |
| Boolean field | tiền tố `is`/`has`/`can` | `isLoading`, `hasError`, `canEdit` |
| l10n biến local | `s` | `final s = AppLocalizations.of(context)!` |

### API / Repository methods
```dart
// GET list   → getAll() hoặc getAll({filters})
// GET single → getById(id)
// POST       → create(body)
// PUT/PATCH  → update(id, body)
// DELETE     → delete(id)
// Tên khác theo action: approve(id), generate(params)
```

---

## Quy tắc đặt tên — Backend (Java/Spring)

### Files & Packages
| Loại | Convention | Ví dụ |
|------|-----------|-------|
| Entity | `PascalCase.java` | `Payroll.java`, `WorkShift.java` |
| DTO | `PascalCaseDTO.java` | `PayrollDTO.java` |
| Service | `PascalCaseService.java` | `PayrollService.java` |
| Controller | `PascalCaseController.java` | `PayrollController.java` |
| Repository | `PascalCaseRepository.java` | `PayrollRepository.java` |
| Migration | `V{n}__lower_snake_desc.sql` | `V89__payroll_pay_type.sql` |

### Classes & Fields
| Loại | Convention | Ví dụ |
|------|-----------|-------|
| Class | `PascalCase` | `PayrollService` |
| Field, method | `camelCase` | `baseSalary`, `generatePayroll()` |
| Constant (`static final`) | `UPPER_SNAKE_CASE` | `DEFAULT_SOCIAL_INS_RATE`, `STANDARD_WORK_DAYS` |
| Enum type | `PascalCase`, values `UPPER_CASE` | `Status { DRAFT, APPROVED, PAID }` |
| DB column | `lower_snake_case` (trong `@Column(name=...)`) | `base_salary`, `pay_type` |
| Boolean field | tiền tố `is` hoặc rõ nghĩa | `isDefault`, `active`, `deleted` |

### Repository methods
```java
// Spring Data JPA naming:
findByX(...)                      // tìm 1 hoặc nhiều theo field X
findByXAndY(...)                  // kết hợp nhiều điều kiện
findByCompanyIdAndActiveTrue(...) // boolean true/false đặt cuối
existsByX(...)                    // check tồn tại
countByX(...)                     // đếm
// Custom query đặt tên mô tả rõ:
findByMonthWithFilters(...)
findByMonthWithDeptScope(...)
```

### Service methods
```java
// CRUD cơ bản:
generate...() / create...()   // tạo mới
get...() / getAll...()        // lấy dữ liệu
update...() / patch...()      // cập nhật
delete...() / remove...()     // xóa
// Action nghiệp vụ:
approve(id)
markAsPaid(id)
recalculate(id)
// Internal/private helper:
private buildFormulaVariables(...)
private getOrThrow(id)        // lấy hoặc throw 404
```

### Controller endpoints
```
GET    /api/v1/{module}           → list
GET    /api/v1/{module}/{id}      → detail
POST   /api/v1/{module}           → create
PUT    /api/v1/{module}/{id}      → full update
PATCH  /api/v1/{module}/{id}      → partial update
DELETE /api/v1/{module}/{id}      → delete
POST   /api/v1/{module}/{id}/approve     → action
POST   /api/v1/{module}/generate         → action đặc biệt
GET    /api/v1/{module}/self      → self-service endpoint
```

### DTO inner classes
```java
// Trong XxxDTO.java:
Response    // trả về client (read)
Upsert      // tạo mới + sửa (write)
PatchRequest// partial update
XxxUpsert   // sub-object upsert (AttendanceUpsert, LeaveUpsert)
XxxSetting  // sub-object response (AttendanceSetting)
```

---

## Database / Payroll
- Tính lương theo quy định Việt Nam: BHXH 8%, BHYT 1.5%, BHTN 1%, thuế TNCN lũy tiến
- `pay_type`: `DAILY` (lương theo ngày) hoặc `HOURLY` (lương theo giờ) — lấy từ `SalaryGrade`
- `standard_work_days`: số ngày công tiêu chuẩn/tháng, lưu trong `Company` (default 22), snapshot vào `Payroll` khi generate

## Entities quan trọng
| Entity | Bảng | Ghi chú |
|--------|------|---------|
| `Company` | `companies` | `standard_work_days` INT default 22 |
| `Employee` | `employees` | FK → Company, SalaryGrade |
| `SalaryGrade` | `salary_grades` | `pay_type` ENUM(DAILY, HOURLY), `base_salary` |
| `Payroll` | `payrolls` | snapshot lương, unique(employee_id, year, month) |
| `Role` | `roles` | `roleViewAllCompany` bool, `roleViewDepartment` FK |
| `Permission` | `permissions` | `code` string, `module`, `requiredRule` |
| `Attendance` | `attendances` | chấm công, FK → Employee |
| `LeaveRequest` | `leave_requests` | nghỉ phép |
| `WorkShift` | `work_shifts` | ca làm việc |

## Migration version hiện tại
Cao nhất: **V12** (`V12__trial_requests.sql`) — V1 là baseline gộp V1–V117 cũ; V6 gắn thiết bị, V7 bắt đổi mật khẩu, V8 sổ phép, V9 nhật ký,
V10 index chấm công, V11 xác thực 2 lớp, V12 yêu cầu dùng thử
→ Migration tiếp theo phải là **V13**

## Vận hành (Bước 2)
- Build frontend: `.github/workflows/frontend-build.yml` (Flutter ghim 3.47.6; APK ký bằng `android/key.properties` do CI tạo từ
  secrets `ANDROID_KEYSTORE_*`; thiếu thì ký debug). Gradle 8.14.3, AGP 8.11.1, Kotlin 2.2.20; Gradle heap 4G (`gradle.properties`).
- Runbook: `docs/runbook.md` (biến môi trường, deploy, rollback, sao lưu/khôi phục DB, sự cố). Đổi cách deploy/biến môi trường → sửa runbook.
- Deploy EB **chạy tay** (workflow_dispatch); push `main` chỉ chạy test. Gói: jar + Procfile + `.ebextensions`.
- Health: `GET /actuator/health` (công khai, không chi tiết); actuator khác bị chặn (SecurityConfig chain 0).
- Mã request: `RequestIdFilter` (header `X-Request-ID`, MDC `rid`, body lỗi `requestId`).
- Nhật ký thao tác: `audit/AuditService` — `audit.log("ACTION").entity(type, id).summary(...).detail(map).save()`.
  Thao tác nhạy cảm mới (sửa công, lương, quyền…) phải ghi nhật ký + thêm nhãn ở `audit_log_screen.dart` và l10n.
  Xem: `/api/v1/audit-logs` (quyền `AUDIT_VIEW`), `/admin/audit-logs` (system admin); FE màn `/audit-logs`.

## Thử nghiệm nội bộ (09/10/2026)
- Báo cáo `docs/pilot-2026-10.md`. Quy tắc rút ra: không tự duyệt/sửa/trả lương của mình (`error.payroll.cannot_process_own`);
  không duyệt công ngày không ca + không dữ liệu; đơn nghỉ nhiều ngày chỉ tính ngày có ca; báo cáo cần quyền xem module
  + phạm vi phòng ban (`ReportController.checkModule`); file báo cáo dùng khoá `excel.report.*`, `excel.enum.*`.
- S3: không có `AWS_ACCESS_KEY` → DefaultCredentialsProvider (IAM role trên EB).
- Bước A: duyệt hàng loạt `POST /api/v1/attendances/approve-bulk` {from,to,departmentId?} (≤ 62 ngày, lô 50 dòng/transaction,
  `entityManager.clear()` sau mỗi lô — phiên JPA open-in-view phình làm chậm dần). Chỉ duyệt ngày đã qua (hôm nay/tương lai → `notEnded`),
  bỏ dòng chấm thiếu một đầu vào/ra (`incomplete`, quản lý duyệt từng dòng). Nghỉ theo giờ trừ giờ nghỉ giữa ca
  (`LeaveService.hoursExcludingBreaks`); có lịch ca ±7 ngày mà ngày xin không có ca → `error.leave.no_shift_days`.
  Tổng quan: ô lương = kỳ gần nhất không còn phiếu nháp (`DashboardService.latestPayroll`).

## Nghỉ phép & lương (Bước 1)
- Quỹ phép tách theo loại: `leave_grants.leave_type_id` = loại được dùng; NULL = quỹ chung cho mọi loại trừ quỹ.
  Trừ quỹ riêng trước, rồi quỹ chung (`LeaveGrantRepository.findUsableGrantsForType`).
- L13 sổ trừ/hoàn `leave_ledger_entries`: mỗi lần trừ ghi phần đổi trên từng quỹ theo đơn gốc (đơn lẻ / đơn cha);
  hoàn phép đảo đúng các dòng đó (quỹ trừ sau hoàn trước). Đơn trước V8 không có sổ → hoàn theo cách cũ.
  API `GET /api/v1/leaves/ledger?employeeId=`; FE: hộp "Lịch sử phép" → tab "Sổ trừ/hoàn".
- Tổng khấu trừ thống nhất = GROSS − NET (`Payroll.totalDeduction`) cho phiếu lương, Excel, báo cáo.
- Lỗi công thức trả chi tiết: `error.formula.invalid|<chi tiết>`, `error.payroll.formula_evaluation_failed|<NV>|[biến] lý do`.

## Bảo mật tài khoản (Bước 1)
- Access token 30 phút (`JWT_EXPIRATION_MS`, mặc định 1800000), refresh 7 ngày; FE tự refresh khi 401.
- Chính sách mật khẩu `core/PasswordPolicy`: ≥ 8 ký tự, có chữ và số — áp ở tạo công ty, tạo NV, tạo tài khoản, import, đổi mật khẩu.
  FE dùng `isStrongPassword` (force_change_password_screen.dart) cho cùng quy tắc.
- `users.must_change_password`: tài khoản do người khác đặt mật khẩu → `true`; `JwtAuthFilter` chỉ cho `/api/v1/auth/*`,
  `GET /api/v1/profile`, `PATCH /api/v1/profile/password`, còn lại 403 `error.auth.password_change_required`.
  FE chuyển về `/change-password`. Test: `Fixture` gỡ cờ cho tài khoản test; seed tạo bằng mật khẩu tạm rồi đổi.
- Mã lỗi có tham số: `"error.x.y|a|b"` → FE thay `{0}`, `{1}` trong bản dịch (error_utils.dart).

## Ca làm (Mốc 2b)
- `WorkShift.shiftType`: `FIXED` | `FLEXIBLE` (linh hoạt: `requiredMinutes` trong khung `startTime–endTime`, thiếu giờ = LATE).
  Loại ca và số phút được snapshot vào `shift_assignments` như giờ ca.
- Tối đa `WorkShiftService.MAX_SHIFTS_PER_DAY` = 4 ca/ngày; kiểm tra chồng giờ dùng `validatePlacement`.
- Mẫu xoay ca `shift_rotations` (`/api/v1/shift-rotations`, sinh phân ca `/{id}/generate`), đổi/nhường ca
  `shift_swap_requests` (`/api/v1/shift-swaps`, quyền duyệt `SHIFT_SWAP_APPROVE`). Màn FE: tab "Xoay ca" ở Ca làm, màn "Đổi ca".

## Màn hình Flutter
| Screen | Path |
|--------|------|
| Payroll (HR) | `screens/payroll/payroll_screen.dart` |
| Payroll (self) | `screens/payroll/self_payroll_screen.dart` |
| Company Settings | `screens/company_settings/company_settings_screen.dart` |
| Employee | `screens/employee/` |
| Attendance | `screens/attendance/` |
| Leaves | `screens/leaves/` |
| Roles & Permissions | `screens/roles/` |
| Shifts | `screens/shift/` |

---

## Quy tắc bổ sung — đúc kết từ thực tế

### Dialog & Navigator.pop
- **BẮT BUỘC**: Trong `builder: (ctx) =>` của `showDialog`/`showInstantDialog`, dùng `Navigator.pop(ctx, value)` — **không dùng** `Navigator.pop(context, value)` (context ngoài sẽ pop màn hình cha thay vì đóng dialog).

### Export/Import Excel — BẮT BUỘC TUYỆT ĐỐI

**Chất lượng dữ liệu export:**
- Export phải **đủ thông tin để import lại được** — tức là user export ra, sửa, rồi import vào phải hoạt động đúng.
- Export phải chứa **ít nhất tất cả các cột đang hiển thị trên màn hình** — không được thiếu cột so với UI.
- Cột dùng để định danh khi import (mã NV, mã ca, ...) phải luôn có trong file export.
- Cột readOnly (không import được) vẫn nên export để user tham khảo (ví dụ: tên phòng ban bên cạnh mã phòng ban).

**Luồng import bắt buộc — KHÔNG BAO GIỜ import thẳng:**
  1. User chọn file
  2. Gọi `/preview-import` → nhận diff list
  3. Hiện `ImportPreviewDialog` (CREATE/UPDATE/NO_CHANGE/warnings)
  4. User xác nhận → mới gọi `/import` thực sự

**Quy tắc kỹ thuật:**
- Backend **bắt buộc** có 2 endpoint riêng: `/preview-import` (readOnly) và `/import` (transactional).
- Import đọc theo **tên cột header** (`importRowsByHeader`) — không đọc theo index cột.
- Tên cột header export phải **khớp chính xác** tên cột trong `IMPORT_COLUMNS` để import hoạt động.
- Tên sheet Excel **không được chứa** `/`, `\`, `?`, `*`, `[`, `]` — dùng `-` thay `/` trong ngày tháng.
- Tên sheet tối đa **31 ký tự**.
- Bỏ dấu tiếng Việt trong tên sheet nếu dùng ký tự đặc biệt.

### Soft Delete
- Tất cả entity quan trọng (Attendance, Employee, ...) dùng **soft delete** (`deleted = true`) — không `DELETE` cứng.
- Repository query phải thêm `AND a.deleted = false` vào mọi query.

### Bulk actions (chấm công)
- Bulk select dùng `Set<String>` (dateKey) cho tab tháng, `Set<int>` (employeeId) cho tab ngày.
- Header checkbox dùng `InkWell` + `IgnorePointer(child: Checkbox(...))` để tránh lỗi tristate không fire onTap.
- Nút approve chỉ hiện khi `attendanceId != null` (đã có record).

### EmployeeDTO
- `Response` phải map đầy đủ: `identityCard`, `bankAccount`, `bankName`, `personalEmail`, `leaveDate`.
- `UpdateRequest` phải có đủ field như `Response` để update từ form.
- `toResponse()` trong service phải map tất cả field — kiểm tra kỹ trước khi ship.

### Kỳ lương (PayrollPeriod)
- Dùng `PayrollPeriod.of(year, month, cutoffDay)` để tính from/to — không hardcode ngày 1 đến cuối tháng.
- `cutoffDay` lấy từ `CompanySettingService.getByCompanyId(companyId).getPayroll().getPayrollCutoffDay()`.

### Hover cursor
- Widget có `onTap`/`onPressed` trên desktop → thêm `MouseRegion(cursor: SystemMouseCursors.click)` để hiện bàn tay khi hover.

### Pre-loading data
- Dữ liệu tham chiếu nặng (grades, departments) → load song song khi mở màn hình cha, truyền vào form qua constructor (`initialGrades`) để tránh lag khi mở form.

### Attendance — hasRecord logic
- Nút duyệt/xóa hiện khi `attendanceId != null` (có record trong DB).
- Nút duyệt luôn hiện (kể cả chưa có check-in/out) để admin có thể duyệt ca trống.
- Nút xóa chỉ hiện khi `attendanceId != null`.

### Ca làm (Shift) — Export bảng ngang
- Sheet phân công ca: hàng = nhân viên, cột = ngày trong kỳ lương, ô = mã ca.
- Tháng export theo `PayrollPeriod` (cutoff day), không phải tháng calendar.
- Freeze 3 cột đầu (Mã NV, Họ tên, Phòng ban) khi export.
- Import phân công ca đọc tên sheet để parse tháng/năm.

---

## Test (backend)

- Chạy: `cd backend && mvn verify` — cần Docker (Testcontainers dựng MySQL 8 thật, chạy toàn bộ migration).
- Integration test kế thừa `support/IntegrationTest`; dữ liệu mẫu lấy từ `Fixture`:
  - `fixture.standardCompany()` — 3 phòng ban, 10 NV, ca HC/DEM/SANG/CHIEU, vai trò Nhân viên/Quản lý chấm công/Kế toán, phép PN/KL, bậc lương NGAY300.
  - `fixture.newCompany()` — công ty trống chỉ có admin.
  - Gọi API qua `api.get/post/put/...(token, url, body)`; mỗi test tự tạo công ty riêng, không cần dọn DB.
- Test gắn `@Tag("known-bug")` tái hiện lỗi đã biết (xem `docs/review-2026-10/danh-gia.html`), bị loại khỏi build mặc định.
  Chạy riêng: `mvn test -Pknown-bugs`. Sửa xong lỗi nào thì **bỏ tag** của test đó để nó thành test hồi quy.
- Sửa lỗi nghiệp vụ → viết/bật test tương ứng trong cùng commit.
- CI: `.github/workflows/test.yml` chạy cho mọi nhánh/PR; `deploy.yml` chỉ deploy khi test xanh.

## Trang giới thiệu & video (10/2026)
- Chạy thử trên máy dev: `dev\start.cmd landing` → http://localhost:8099 (`dev/landing-server.ps1`, HttpListener có Range cho video).
- `landing/`: trang tĩnh `index.html` (cấu hình `window.BOSSKIN`: appUrl, contactEmail, contactPhone) + `assets/` (ảnh webp, video).
- Video `landing/assets/bosskin-gioi-thieu.mp4` dựng lại bằng `landing/video/` (seed công ty hư cấu "Nội thất An Phát" trên DB thử,
  chụp màn hình bằng Playwright, giọng edge-tts `vi-VN-HoaiMyNeural`, dựng bằng `make_video.py`). Hướng dẫn: `landing/README.md`.
- Form dùng thử → `POST /api/v1/public/trial-requests` (công khai, `/api/v1/public/**` permitAll): ô bẫy bot `website`,
  trùng số điện thoại trong 10 phút bỏ qua, giới hạn `app.trial-request.max-per-ip-hour` (mặc định 5, bộ nhớ 1 instance),
  bắt buộc `consent`. System admin xử lý ở `/admin/trial-requests` (lọc, đổi trạng thái NEW/CONTACTED/TRIAL/REJECTED + ghi chú,
  `count-new`, xuất Excel); FE tab "Yêu cầu dùng thử" (`screens/admin/trial_requests_tab.dart`). Chưa gửi email báo (chưa có SMTP).
- Nguồn yêu cầu dùng thử = Supabase `bosskin` (`apcppqwwnoyliwlhqtyx`), bảng `trial_requests`: trang ghi thẳng; backend đọc/ghi qua
  `service/trial/TrialRequestStore` (`SupabaseTrialRequestStore` khi có `SUPABASE_URL` + `SUPABASE_SECRET_KEY`, ngược lại `JpaTrialRequestStore` — MySQL V12).
  Bảng Supabase `bosskin` (`apcppqwwnoyliwlhqtyx`), bảng `trial_requests`
  (SQL: `landing/supabase/001_trial_requests.sql`; anon chỉ INSERT, trigger chống spam). Đổi bảng → sửa file SQL đó + migration Supabase.
- Host: Netlify (`netlify.toml` ở gốc: base `landing`, không build). `apiUrl` trống → form gửi Netlify Forms (`dung-thu`, ô bẫy `website`);
  có `apiUrl` → API BossKin. `appUrl` trống → ẩn nút Đăng nhập.
- Đổi tính năng/giao diện chính → cập nhật nội dung trang (và chụp lại ảnh/video nếu màn hình đổi nhiều).
