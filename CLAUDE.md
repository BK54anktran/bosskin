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
   - code đổi API/nghiệp vụ → cập nhật `docs/` (kế hoạch, đánh giá, tài liệu hệ thống `docs/he-thong/`);
   - đổi controller / quyền / schema → sinh lại `docs/he-thong/{api,csdl,quyen}.md` bằng `tools/docs/gen_he_thong.py`
     (CI chạy `--check`);
   - đổi schema → migration Flyway mới + entity/DTO + tài liệu;
   - đổi giao diện/luồng → cập nhật design, chuỗi l10n và trang trợ giúp `help/src/*.md` (chụp lại ảnh nếu màn đổi);
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
  ca linh hoạt, phân ca 9–10/2026, mẫu xoay ca + phân ca xoay tháng 11 cho 2 công nhân (bỏ qua ngày lễ), lịch "Xưởng: T7 làm sáng" (`FFFFFHO`)
  cho Xưởng sản xuất, quản lý trực tiếp (GĐ → NS/KTT/QĐ, KTT → KTV, QĐ → 3 công nhân) + mốc tương lai 01/12/2026
  (Nam lên quản đốc), 8 hợp đồng (Mai hết hạn 31/10 → cần gia hạn, HĐ mới nháp; phụ lục tăng lương Tài 16/09, Nam 01/12),
  MST + sổ BHXH cho 8 NV, 4 người phụ thuộc (2 con GĐ, mẹ QĐ hết giảm trừ từ 09/2026, con Tài chờ MST), vai trò Nhân sự xem đủ dữ liệu nhạy cảm,
  4 loại phép, công đã duyệt
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
- **Infra**: `docker-compose.yml` ở root (api + web cho Vibe Host / VPS, CSDL ngoài); AWS dạng file ở `infra/aws/`.
  Bản web đọc địa chỉ API lúc chạy: biến `API_HOST` của container Nginx → `env.js` → `window.BOSSKIN_API_HOST` (`core/config/runtime_host*.dart`).

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
- Không còn vai trò cố định: vai trò theo công ty = tập mã quyền + phạm vi phòng ban (tạo công ty sinh sẵn "Admin" và "Nhân viên").
  Quyền trực tiếp của user ghi đè quyền vai trò theo module. Chi tiết: `docs/he-thong/phan-quyen.md`, danh mục `docs/he-thong/quyen.md`.
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
- Thông số thuế / BH theo ngày hiệu lực ở bảng `tax_policies` (V13, bước I): giảm trừ bản thân / người phụ thuộc, biểu thuế (JSON),
  mức tham chiếu × hệ số = trần BHXH/BHYT, lương tối thiểu 4 vùng × hệ số = trần BHTN (`companies.min_wage_region`).
  Kỳ lương dùng chính sách hiệu lực ở **ngày cuối kỳ** (`TaxPolicyService.forDate(period.to())`); `PIT_VN(...)` dùng biểu của kỳ
  (`FormulaEngine.withPitBrackets`). Không viết cứng mức giảm trừ / biểu thuế trong code nữa. System admin sửa ở `/admin/tax-policies`
  (tab "Thuế & BH", nhật ký `TAX_POLICY_*`). Biến: `PERSONAL_DEDUCTION`, `DEPENDENT_DEDUCTION`, `DEPENDENTS` (0 tới bước M),
  `FAMILY_DEDUCTION`, `INSURANCE_BASE/CAP`, `UNEMPLOYMENT_BASE/CAP`. Phiếu lưu snapshot `family_deduction`, `insurance_base`.
  Test tạo chính sách phải dùng ngày xa (vd. 2099) và xoá lại — bảng dùng chung mọi công ty.
- `pay_type`: `DAILY` (lương theo ngày) hoặc `HOURLY` (lương theo giờ) — lấy từ `SalaryGrade`
- `standard_work_days`: số ngày công tiêu chuẩn/tháng, lưu trong `Company` (default 22), snapshot vào `Payroll` khi generate

## Entities quan trọng
| Entity | Bảng | Ghi chú |
|--------|------|---------|
| `Company` | `companies` | `standard_work_days` INT default 22 |
| `Employee` | `employees` | FK → Company, SalaryGrade |
| `SalaryGrade` | `salary_grades` | `pay_type` ENUM(DAILY, HOURLY), `base_salary` |
| `Payroll` | `payrolls` | snapshot lương, unique(employee_id, year, month) |
| `TaxPolicy` | `tax_policies` | thông số thuế / BH theo `effective_from`, dùng chung mọi công ty |
| `Role` | `roles` | `roleViewAllCompany` bool, `roleViewDepartment` FK |
| `Permission` | `permissions` | `code` string, `module`, `requiredRule` |
| `Attendance` | `attendances` | chấm công, FK → Employee |
| `LeaveRequest` | `leave_requests` | nghỉ phép |
| `WorkShift` | `work_shifts` | ca làm việc |
| `LaborContract` | `labor_contracts` | hợp đồng; phụ lục `contract_appendices`, phụ cấp `contract_allowances` (V16) |
| `EmployeeDependent` | `employee_dependents` | người phụ thuộc, giảm trừ theo tháng (V17) |
| `EmployeeDocument` | `employee_documents` | tài liệu nhân sự, loại ở `document_types` (V18) |

## Migration version hiện tại
Cao nhất: **V23** (`V23__shift_registration.sql`) — V1 là baseline gộp V1–V117 cũ; V6 gắn thiết bị, V7 bắt đổi mật khẩu, V8 sổ phép, V9 nhật ký,
V10 index chấm công, V11 xác thực 2 lớp, V12 yêu cầu dùng thử, V13 thuế/BH theo ngày hiệu lực (`tax_policies`), V14 ngày lễ + lịch làm việc,
V15 quá trình công tác + quản lý trực tiếp + chế độ duyệt, V16 hợp đồng lao động + phụ lục + phụ cấp,
V17 MST / sổ BHXH / người phụ thuộc / BH công ty đóng / quyền xem dữ liệu nhạy cảm, V18 tài liệu nhân sự,
V19 bộ đếm mã NV + giá trị cũ của yêu cầu sửa hồ sơ, V20 khôi phục bậc lương / chức vụ bị xoá nhầm khi NV còn dùng (sửa dữ liệu, không đổi lược đồ),
V21 hiện lại NV bị nút Nghỉ việc cũ xoá mềm (sửa dữ liệu: INACTIVE + ngày nghỉ = ngày khoá tài khoản),
V22 định danh công ty (đuôi email unique + đổi mã NV `EMP…` → `<mã công ty>…`), V23 đăng ký lịch làm việc
→ Migration tiếp theo phải là **V24**

## Vận hành (Bước 2)
- Build frontend: `.github/workflows/frontend-build.yml` (job check → web + apk song song trên 2 máy, APK lỗi không chặn gói web; chạy khi push `main` + PR, commit mới huỷ lượt cũ cùng nhánh; Flutter ghim 3.47.6; APK ký bằng `android/key.properties` do CI tạo từ
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

## Ngày lễ & lịch làm việc (Bước J)
- V14: `holidays` (`company_id` NULL = mẫu hệ thống theo năm; `type` HOLIDAY | COMPENSATORY | SWAP_WORKDAY, `paid`; unique `(company_key, date_key)`),
  `work_calendars` (`week_pattern` 7 ký tự T2→CN: F cả ngày / H nửa ngày / O nghỉ, mặc định `FFFFFOO`; ≤ 1 lịch `is_default`/công ty),
  `departments.work_calendar_id`, `companies.standard_days_from_calendar`, `payrolls.standard_work_days` decimal(5,2).
- Copy-on-write: công ty chưa chỉnh năm nào thì dùng mẫu năm đó; lần thêm/sửa/xoá đầu tiên chép mẫu năm đó sang công ty.
  System admin sửa mẫu ở `/admin/holidays` (tab "Ngày lễ mẫu"). Mẫu 2026–2027: ngày liền kề 2/9, nghỉ bù / hoán đổi phải đối chiếu thông báo hằng năm.
- Lịch của NV: lịch phòng ban → phòng cha → mặc định công ty (`WorkCalendarService`, snapshot `CalendarView`). Không viết cứng T7/CN nữa.
- API `/api/v1/holidays` (?year, CRUD, export, preview-import/import theo ngày, cột "Xóa (x)"), `/api/v1/work-calendars` (CRUD, `default`,
  `departments`, `view?from&to` — đọc được với CALENDAR_VIEW / SHIFT_VIEW / ATTENDANCE_VIEW / ATTENDANCE_SELF). Quyền `CALENDAR_VIEW`/`CALENDAR_MANAGE`.
  Nhật ký `HOLIDAY_*`, `HOLIDAY_TEMPLATE_*`, `WORK_CALENDAR_*`.
- Lương: bật "Công chuẩn theo lịch làm việc" → `STANDARD_WORK_DAYS` = F 1 / H 0,5, SWAP_WORKDAY +1, lễ có lương + trọng số thứ đó, lễ không lương 0;
  tắt → số cố định như cũ. Biến `HOLIDAY_DAYS`, `HOLIDAY_OT_HOURS`. Ví dụ 11/2026 lịch mặc định = 21 (24/11 nghỉ có lương), `FFFFFHO` = 23.
- Đơn nghỉ 1 ngày vào ngày lễ nghỉ → `error.leave.holiday`; đơn nhiều ngày bỏ qua ngày lễ nghỉ. Sinh xoay ca có `skipHolidays`.
- FE: Cài đặt công ty có tab "Chung" + "Lịch làm việc" (cần CALENDAR_VIEW); lưới ca và bảng công tô màu ngày lễ / ngày nghỉ (`holidayName`).
  Test: `WorkCalendarTest`.

## Quá trình công tác & quản lý trực tiếp (Bước K)
- V15: `employee_job_histories` (mỗi dòng = ảnh chụp phòng ban / chức vụ / bậc lương / quản lý từ `effective_from`; `change_type`
  HIRE | TRANSFER | PROMOTION | SALARY_CHANGE | MANAGER_CHANGE | OTHER; `applied`), `employees.manager_id`, `companies.approval_mode`
  (PERMISSION mặc định | MANAGER_THEN_HR), `manager_approved_by/_at/_note` trên `leave_requests`, `attendance_requests`, `shift_swap_requests`
  (interface `ManagerApprovable`), `payrolls.department_id/_name`.
- `JobHistoryService`: dòng hiện hành = mới nhất ≤ hôm nay, `sync()` chép vào `employees`; `@Scheduled` 00:05 VN `applyDue()` áp mốc tới ngày.
  Tạo NV ghi HIRE; sửa form / import đổi 1 trong 4 trường → `recordIfChanged` ghi mốc hôm nay. Chỉ xoá mốc chưa tới ngày
  (`error.job_history.past_readonly`). Quản lý: cùng công ty, không tự quản lý, không vòng (`error.employee.manager_*`). Nhật ký `JOB_HISTORY_*`.
- Nghỉ việc **không xoá** NV (13/10/2026): `POST /api/v1/employees/{id}/resign` {leaveDate ≤ hôm nay, ≥ ngày vào làm} → INACTIVE,
  khoá tài khoản, `clearManager`, gỡ phân ca sau ngày nghỉ chưa có công (`WorkShiftService.removeAssignmentsAfter`); `/reinstate` mở lại.
  Nhật ký `EMPLOYEE_RESIGN` / `EMPLOYEE_REINSTATE`. `DELETE /employees/{id}` vẫn là xoá mềm (ẩn hẳn), FE không gọi nữa.
- `EmployeeDTO.UpdateRequest.managerId` có cờ "đã gửi": không gửi = giữ, gửi null = bỏ quản lý. Lưu ý PUT nhân viên không gửi
  `positionId` / `salaryGradeId` thì hai trường đó bị xoá (hành vi cũ).
- Lương: `effectiveOn(emp, period.to())` → phòng ban + bậc (mốc chưa có bậc → bậc hiện tại); phiếu lưu phòng ban; Excel / báo cáo / lọc phòng ban
  dùng `COALESCE(p.departmentId, e.department.id)`.
- Chế độ duyệt (`ManagerApprovalService`): bật MANAGER_THEN_HR + NV có quản lý còn làm → HR duyệt cuối bị 409 `error.approval.manager_pending`
  tới khi quản lý duyệt (người duyệt chính là quản lý → ghi luôn 2 bước). Quản lý dùng `/api/v1/team-approvals` (GET, `/count`,
  `POST /{LEAVE|ATTENDANCE|SWAP}/{id}/approve|reject`), quyền theo quan hệ quản lý; từ chối đơn nghỉ hoàn phép. Báo đẩy FCM cho quản lý khi có đơn
  (`FcmService.sendSimple`). Nhật ký `MANAGER_APPROVE` / `MANAGER_REJECT`.
- API `/api/v1/employees/{id}/job-histories` (GET EMPLOYEE_VIEW, POST + EMPLOYEE_UPDATE), `DELETE /api/v1/employees/job-histories/{id}`,
  `/api/v1/org-chart` (EMPLOYEE_VIEW, lọc phạm vi).
- FE: hộp "Quá trình công tác" (`employee/job_history_dialog.dart`, nút ở danh sách NV), `ManagerDropdown` trong form NV, màn `/org-chart`
  (`employee/org_chart_screen.dart`), màn `/team-approvals` (menu chỉ hiện khi `TeamApprovalService.visible`), `StatusBadge.managerStep`
  ở danh sách đơn nghỉ / sửa công / đổi ca, chọn chế độ ở Cài đặt công ty. Test: `JobHistoryTest`.

## Hợp đồng lao động (Bước L)
- V16: `labor_contracts` (DRAFT | ACTIVE | TERMINATED; "hết hạn" = ACTIVE có `end_date` < hôm nay, không lưu; unique `contract_no_key` theo công ty),
  `contract_appendices` (trường NULL = giữ giá trị trước; `overrides_allowances` thay cả bộ phụ cấp), `contract_allowances`
  (`appendix_id` NULL = phụ cấp gốc; `code` → biến `ALLOWANCE_<code>`, cờ `insurable` / `taxable`), `companies.contract_expiry_warning_days` (30).
  Migration chuyển mỗi NV có `contract_salary` > 0 thành HĐ INDEFINITE ACTIVE `HD-<mã NV>` từ ngày vào làm.
- `ContractService`: kiểm loại (FIXED_TERM ≤ 36 tháng, INDEFINITE không có ngày kết thúc, PROBATION / SEASONAL cần ngày kết thúc),
  chặn 2 HĐ không nháp chồng ngày (`error.contract.overlap|<số HĐ>`), phụ lục phải sau ngày bắt đầu và trong thời hạn.
  Chấm dứt: `termination_date` = ngày làm cuối. Nhật ký `CONTRACT_*`.
- `employees.contract_salary` **chưa xoá** (chờ chủ dự án đồng ý): dự phòng cho NV chưa có HĐ, tự đồng bộ = lương HĐ hiệu lực hôm nay
  (`syncEmployeeSalary` khi lưu HĐ / phụ lục và `dailyJob` 07:30 VN). NV đã có HĐ không nháp → PUT nhân viên đổi lương = 409
  `error.contract.salary_managed_by_contract`; import NV bỏ qua cột lương HĐ.
- Lương (`ContractService.payTerms`): `CONTRACT_SALARY` = bình quân lương từng đoạn theo công chuẩn lịch (`calendar.periodDays`), ngày không có HĐ
  bỏ qua; `INSURANCE_SALARY` (mức riêng hoặc lương + phụ cấp đóng BH, ở ngày cuối kỳ có HĐ) → `INSURANCE_BASE` / `UNEMPLOYMENT_BASE`;
  `ALLOWANCE_<mã>`, `CONTRACT_ALLOWANCE`, `TAXABLE_ALLOWANCE`, `NON_TAXABLE_ALLOWANCE`. Không có HĐ → như cũ. `FormulaEngine` nhận mọi
  `ALLOWANCE_*` (thiếu = 0); mã `MANUAL` cấm (trùng `ALLOWANCE_MANUAL`).
- Cảnh báo: `/expiring?days=` (ACTIVE kết thúc ≤ hôm nay + N hoặc đã quá hạn, NV chưa nghỉ, chưa có HĐ nối tiếp không nháp), mục
  `contractExpiring` ở `/dashboard/risks` (khi có CONTRACT_VIEW), FCM cho tài khoản có CONTRACT_VIEW khi còn đúng N / 7 / 0 ngày.
- API `/api/v1/contracts` (CONTRACT_VIEW + phạm vi; sửa CONTRACT_EDIT; xoá CONTRACT_DELETE), `/{id}/activate`, `/{id}/terminate`,
  `/{id}/appendices`, `/appendices/{id}`, `/export` (sheet hợp đồng + sheet phụ cấp), `/preview-import`, `/import` (sheet 2 vắng = giữ phụ cấp).
- FE: màn `/contracts` (`screens/contracts/`), `DateField` (widgets), `ManagerDropdown(allowNone: false)` để chọn NV, `formatMoney`
  (text_utils), ô báo trước ở Cài đặt công ty. Mã lỗi lồng (`error.contract.import_row|HD|error.contract.overlap|HD0`) được
  `error_utils` dịch đệ quy. Test: `ContractTest`.
- Chủ dự án chọn **giữ** `employees.contract_salary` và `salary_histories` (10/10) — không xoá.

## Thuế & bảo hiểm của nhân viên (Bước M)
- V17: `employees.tax_code`, `social_insurance_no`, `health_insurance_place`, `insurance_join_date`; `employee_dependents` (quan hệ
  CHILD/SPOUSE/PARENT/OTHER, `deduction_from` / `deduction_to` lưu ngày 01, NULL = chưa kết thúc; `registration_status`
  NOT_REGISTERED không tính, PENDING / REGISTERED được tính; xoá mềm); `companies.employer_*_rate` (0.175 / 0.03 / 0.01);
  `payrolls.dependents`, `employer_social_ins`, `employer_health_ins`, `employer_unemployment_ins`.
- Che dữ liệu (đóng một phần D5): `core/SensitiveData` — thiếu `EMPLOYEE_SENSITIVE_VIEW` (chỉ cấp sẵn cho Admin) thì CCCD, số tài khoản,
  MST, sổ BHXH (cả MST / CCCD người phụ thuộc) trả `****1234` ở `EmployeeService.toResponse`, Excel NV (2 đường), báo cáo.
  Gửi lại đúng bản che khi PUT / import → giữ giá trị cũ (`SensitiveData.incoming`). Job nền (không có người dùng) xem đủ.
- API `/api/v1/dependents?employeeId=` (EMPLOYEE_VIEW + phạm vi), POST / PUT / DELETE (EMPLOYEE_UPDATE, nhật ký `DEPENDENT_*`),
  `/self` (NV xem ở Hồ sơ, không che). Lỗi `error.dependent.invalid_period|not_found|employee_change`.
- Lương: `DEPENDENTS` = `DependentService.countDeductible(employeeId, YearMonth(năm, tháng phiếu))`; lương đóng BH có sàn
  `INSURANCE_FLOOR` = lương tối thiểu vùng khi `INSURANCE_SALARY` > 0; BH công ty đóng = `INSURANCE_BASE` × tỷ lệ (BHTN dùng
  `UNEMPLOYMENT_BASE`), không vào NET. Cài đặt công ty `payroll.employer{Social,Health,Unemployment}Percent` (%, 0–50,
  `error.company.employer_rate_invalid`).
- Báo cáo: lương thêm cột "BH công ty đóng" + "Tổng chi phí"; `/reports/insured-employees` (NV đang làm có ngày tham gia BH hoặc số sổ),
  `/reports/dependents` (EMPLOYEE_VIEW + phạm vi phòng ban).
- FE: mục "Thuế & bảo hiểm" ở form NV, hộp `employee/dependents_dialog.dart` (nút ở danh sách NV), `profile/my_dependents_card.dart`,
  `PayslipTaxInfo(showEmployerCost:)`, 3 ô tỷ lệ ở Cài đặt công ty, 2 báo cáo mới. Test: `DependentTest`.

## Tài liệu nhân sự (Bước N)
- V18: `document_types` (theo công ty, mã unique qua `code_key`, `required`, `has_expiry`; 6 loại mặc định — công ty mới do
  `DocumentService.createDefaultTypes` cấp trong `CompanyService.create`), `employee_documents` (`file_key` không phải URL, ngày cấp /
  hết hạn, `contract_id` phải cùng NV, `status` PENDING/APPROVED/REJECTED, xoá mềm). Quyền `EMPLOYEE_DOCUMENT_VIEW` (phạm vi phòng ban) /
  `EMPLOYEE_DOCUMENT_EDIT`, cấp sẵn cho Admin.
- File riêng tư: `DocumentStorageService` — `app.documents.storage` `s3` (presigned GET) | `local` (thư mục, link
  `/api/v1/public/document-files?t=` ký HMAC bằng `jwt.secret`); trống = s3 khi có bucket. TTL `link-ttl-seconds` (300).
  Test chạy `local`. Không dùng `UploadController` / URL công khai cho giấy tờ cá nhân. PDF / ảnh / Word ≤ 10 MB.
- API `/api/v1/document-types`, `/api/v1/employee-documents` (+ `/pending`, `/expiring?days=`, `/missing`, `/{id}/link`,
  `/{id}/approve|reject`, `/self`, `/self/{id}/link`, `DELETE /self/{id}` khi còn chờ). Nhật ký `DOCUMENT_TYPE_*`, `DOCUMENT_UPLOAD|UPDATE|
  DELETE|APPROVE|REJECT|VIEW` (mỗi lần lấy link). NV tự gửi = PENDING, không tự duyệt bản của mình (`error.document.cannot_review_own`).
- Sắp hết hạn: bản đã duyệt hết hạn muộn nhất mỗi NV × loại, trong `companies.contract_expiry_warning_days`; Tổng quan
  `documentExpiring`; báo đẩy 07:35 (N / 7 / 0 ngày). Thiếu bắt buộc: chưa có bản đã duyệt còn hạn.
- FE: `widgets/document_widgets.dart` (`DocumentTile`, `DocumentUploadDialog`, `downloadDocument`), `employee/employee_documents_dialog.dart`,
  màn `/documents` (`screens/documents/`), `profile/my_documents_card.dart`; `pickDocumentFile()` (web: PDF / ảnh / Word, mobile: ảnh).
  Test: `DocumentTest` (`Api.uploadWith`, `Api.rawGet`).

## Dọn mục còn mở trước UAT (O–Q, 10/10/2026)
- Mã NV: `EmployeeCodeService.next(companyId)` (bảng `employee_code_counters`, V19; `SELECT … FOR UPDATE`, cần transaction của người gọi —
  `Propagation.MANDATORY`), dạng `<mã công ty>00001` (V22, trước là `EMP00001`), bỏ qua mã đã dùng kể cả NV đã xoá. Không dùng `count + 1` nữa. Cột tên `last_seq`
  (`last_value` là từ khoá MySQL 8).
- Phòng ban: đổi cha chặn chọn con / cháu (`error.department.parent_cycle`), `recomputeLevels(companyId)` sau mỗi lần đổi cha; import gắn cha ở
  bước sau (thứ tự dòng tuỳ ý), chặn vòng (`error.import.department_cycle|mã`), không xoá phòng còn NV (`error.import.department_has_employees|mã|số`).
  Đếm NV theo phòng: `EmployeeRepository.countByDepartment` (GROUP BY), không dùng `d.getEmployees().size()` trong danh sách.
- Excel (`util/ExcelText`): cột chữ xuất định dạng Text ("@", cả default column style), đọc ô số theo định dạng "000…" giữ số 0;
  `EmployeeDTO.ImportRow.setPhone/setIdentityCard` tự bù số 0 (SĐT 9 số, CCCD 10–11 số, CMND 8 số).
- Mật khẩu: `PasswordPolicy.generate(n)` (dùng chung với system admin). Import để trống mật khẩu → ngẫu nhiên. `POST /api/v1/users/{id}/reset-password`
  (USER_MANAGE + phạm vi, không cho chính mình `error.user.cannot_reset_self`) trả `{password}`; `POST /api/v1/users/initial-passwords` trả file Excel
  mật khẩu tạm cho tài khoản còn `must_change_password` (`error.user.no_pending_accounts`). Nhật ký `USER_RESET_PASSWORD`, `USER_ISSUE_INITIAL_PASSWORDS`.
  FE: chìa khoá trên thẻ người dùng + nút "Xuất mật khẩu tạm" ở tab Người dùng (`roles_screen.dart`).
- Yêu cầu sửa hồ sơ: lọc / đếm / duyệt theo phạm vi `EMPLOYEE_UPDATE`, không tự duyệt (`error.profile.cannot_process_own`), lưu `old_*` + `processed_at`;
  đơn đã duyệt trả `current*` = giá trị trước khi duyệt. Nhật ký `PROFILE_EDIT_APPROVE` / `PROFILE_EDIT_REJECT`.
- Phân ca: `GET /shifts/assignments` lọc theo phạm vi SHIFT_VIEW (`WorkShiftService.inShiftScope`), `/assignments/employee/{id}` ngoài phạm vi 403.
  Ca lấy `findByCompanyIdAndActiveTrue`, không `findAll()`.
- Phạm vi phòng ban gửi lên (vai trò, người dùng): `DeptScopeService.requireValidScopeIds` — chỉ phòng của công ty hoặc -1/-2/-3.
  Danh sách người dùng: `UserRepository.findForListing` + `UserPermDeptScopeRepository.findScopesMaps` (theo lô).
- Chưa làm (chờ chốt): job dọn phiên / nhật ký / file tạm (D12), chia tỷ lệ bậc lương giữa kỳ (L17), phân trang báo cáo (D10).
- Test FE: `frontend/test/` (`flutter test`, CI frontend-build) — `AuthService.debugSetUser`, `debugLookupServerKey` chỉ cho test.
  Mã lỗi backend mới phải có bản dịch vi + en: `tools/ci/check_error_keys.py` (CI backend) và `error_translations_test.dart`.
- Diễn tập sao lưu / khôi phục: `tools/ops/backup_restore_drill.sh` (runbook mục 5). Kịch bản nghiệm thu: `docs/uat-kich-ban.md`.

## Định danh công ty (V22, 13/10/2026)
- `core/CompanyIdentity`: mã công ty 2–12 ký tự `[A-Z][A-Z0-9]` = **tiền tố mã NV** (`EmployeeCodeService` cấp `<MÃ>00001`); khi tạo không trùng
  và không là tiền tố của mã khác (`error.company.code_prefix_conflict|mã`); sửa công ty (`UpdateCompanyRequest`) không đổi mã (`error.company.code_immutable`).
- Đuôi email `companies.domain` bắt buộc khi tạo, chuẩn hoá chữ thường bỏ "@", unique (`error.company.domain_duplicate|đuôi`); đổi đuôi khi còn tài khoản
  đuôi cũ → `error.company.domain_accounts_mismatch|đuôi|số`. Mọi tài khoản mới (admin đầu, tạo NV, `POST /users`, import Excel) phải `…@domain`
  (`error.email.domain_mismatch|đuôi`); mã NV nhập tay phải bắt đầu bằng mã công ty (`error.employee.code_prefix|MÃ|mã`). Đồng bộ tài khoản từ NV bỏ qua email sai đuôi.
- Đăng nhập trả `companyCode` / `companyDomain` (FE `AuthUser`); FE kiểm bằng `core/utils/company_identity_utils.dart`. Hộp "Sửa công ty" ở /admin (mã chỉ xem).
- Danh mục khác (phòng ban, ca, loại phép, bậc lương…) mã unique theo công ty, tra cứu luôn lọc `company_id` — không gắn tiền tố.
- Test: `Fixture.newCompany()` đặt đuôi `<mã>.test`, dùng `c.email("x")`; `CompanyIdentityTest`.

## Đăng ký lịch làm việc (V23, 14/10/2026)
- Thiết kế + quyết định của chủ dự án: `docs/thiet-ke/dang-ky-ca.md`. Công ty bật / tắt (`companies.shift_registration_enabled`, cài đặt
  `shiftRegistration.enabled`); tắt → API 403 `error.shift_registration.disabled`, FE ẩn menu / tab qua `CompanyFeatureService`.
- `shift_registration_rounds` (DRAFT | OPEN | CLOSED, ≤ 62 ngày, phòng ban + phòng con, hạn chót tự đóng — job 5 phút, hai đợt chung phòng không chồng ngày)
  + `shift_registrations` (`kind` SHIFT | CUSTOM | ANY = rảnh cả ngày, ≤ 2 khung / ngày, PENDING | APPROVED | REJECTED, `assignment_id`).
- Quyền `SHIFT_REGISTRATION_SELF` (vai trò mặc định "Nhân viên") / `SHIFT_REGISTRATION_MANAGE` (cần `SHIFT_VIEW`, phạm vi phòng ban theo SHIFT_VIEW).
- Duyệt theo ngày `POST /shift-registration-rounds/{id}/days/{date}/approve {anyShiftId?}` hoặc từng ô → `WorkShiftService.assign`
  (mỗi ô một giao dịch, lỗi trả trong `skipped`); không tự duyệt của mình. Đăng ký chỉ là nguyện vọng, quản lý vẫn xếp ca bình thường.
- `ShiftRegistrationService`, `ShiftRegistrationController`; FE `shift/shift_registration_tab.dart` (tab "Đăng ký lịch" ở Ca làm),
  `shift/my_shift_registration_screen.dart` (`/shift-registration`), `core/utils/shift_registration_utils.dart`. Test: `ShiftRegistrationTest`.
- Chưa làm: xuất Excel lưới, nhắc trước hạn chót, ảnh trợ giúp, đợt mẫu trong seed.

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
| Contracts | `screens/contracts/` |

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
- Đầu cột xuất theo ngôn ngữ người dùng → khi đọc phải khớp **mọi bản dịch** (`excelI18n.allValues(key)`), không so chuỗi tiếng Việt cứng.
- Nhập lại nguyên file vừa xuất phải là "không đổi" ở cả xem trước lẫn nhập thật (không ghi đè, không tạo dòng rỗng). Bảng công /
  chấm công theo ngày so với chính dòng bảng công như file xuất (`TimesheetSource`, giờ làm tròn, giờ nghỉ ca, tăng ca tính sẵn)
  và chỉ ghi ô đã đổi. Kiểm thử vòng xuất → sửa → nhập: `ExcelRoundTripTest` (thêm luồng Excel mới → thêm ca test ở đó).
- File mẫu nhập (`util/ExcelTemplate`): `GET /api/v1/excel/template?types=`, `/contracts/template`, `/holidays/template` — sinh từ chính danh sách
  cột nhập (chỉ tiêu đề, cột nhập được) + sheet "Hướng dẫn" CUỐI (màn nhập đọc sheet theo thứ tự). Ví dụ / ghi chú cột: `excel.example.X` /
  `excel.note.X` theo `excel.col.X` trong excel_*.properties. FE `widgets/excel_template_button.dart`. Excel chung: dòng để trống cột Lệnh bị
  bỏ qua; xem trước coi mã do sheet trước cùng file tạo (CREATE/MERGE) là có (`UniversalExcelService.PENDING_REFS`).

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

### Màu & giao diện tối (Bước F)
- **Không viết cứng màu nền / chữ / viền** (`Colors.white`, `Colors.grey[600]`, `Color(0xFF64748B)`, nền "-50" như `0xFFE3F2FD`):
  dùng `AppTheme.background` (thẻ / ô bảng), `surface` (nền trang / ô nhập), `surfaceAlt` (dòng xen kẽ), `textPrimary`,
  `textSecondary`, `textMuted`, `border`, `AppTheme.tint(màu)` (nền nhạt theo màu trạng thái). Màu thương hiệu / trạng thái
  (`primary`, `error`, `warning`, `secondary`) giữ nguyên; chữ trắng trên nền màu vẫn dùng `Colors.white`.
- Các màu theo chế độ là **getter**, không dùng trong `const` (`TextStyle(color: AppTheme.textSecondary)`, không `const TextStyle(...)`);
  hằng toàn cục chứa các màu này phải là getter (`Color get x => AppTheme.border;`), không `final` / `const`.
- `ThemeController` (core/theme) lưu chế độ (theo máy / sáng / tối), đặt `AppTheme.isDark`; `main.dart` dựng lại cả cây khi đổi
  (`KeyedSubtree(ValueKey(dark))`). Nút chọn ở Hồ sơ (`profile/appearance_card.dart`). Cổng /admin giữ nền tối riêng của nó.

### Hạ tầng AWS & chuyển dữ liệu (Bước E)
- `infra/aws/bosskin.yaml`: stack CloudFormation (EB Corretto 17, RDS MySQL 8, S3, IAM, Secrets Manager, cảnh báo SNS); hướng dẫn
  `infra/aws/README.md`. Kiểm bằng `cfn-lint infra/aws/*.yaml` (CI `infra-lint.yml`). Đổi biến môi trường / tài nguyên → sửa stack + runbook.
  S3: chỉ `company-*/avatars/*`, `company-*/images/*` đọc công khai; thư mục ảnh mới cần đọc công khai → thêm vào bucket policy.
- Excel chung nhập theo `@Order` của descriptor (phòng ban 10 → chức vụ 20 → bậc lương 30 → ca 40 → loại phép 50 → biến 60 → công thức 70
  → nhân viên 80 → số dư phép 90 → phân ca 100 → chấm công 110 → lương 120). Descriptor mới phải có `@Order` theo phụ thuộc.
- Nhập phân ca: xoá + thêm trong cùng transaction mới (`ShiftExcelService.replaceOneInNewTx`), không xoá ở transaction ngoài.
  Số dư phép: một quỹ = (NV, loại phép, ngày cấp), MERGE cập nhật quỹ đó, không tạo thêm.
- Mẫu nhập dữ liệu thật `tools/onboarding/mau/` (tạo lại bằng `make_template.py` từ file xuất của công ty trống), hướng dẫn
  `docs/chuyen-du-lieu.md`; đối chiếu pilot `tools/onboarding/doi_chieu.py`. Đổi cột nhập Excel → tạo lại mẫu (quy tắc 2).
- Checklist thử điện thoại: `docs/thu-dien-thoai.md` (bước D) — tính năng mobile mới thì thêm kịch bản.

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
- CI: workflow chỉ chạy khi push `main` + PR (nhánh làm việc không chạy riêng), commit mới huỷ lượt cũ; `test.yml` (Backend tests) đang tắt trên GitHub — bật lại ở tab Actions; `deploy.yml` (EB, chạy tay, đang tắt) chỉ deploy khi test xanh.

## Trang giới thiệu & video (10/2026)
- Chạy thử trên máy dev: `dev\start.cmd landing` → http://localhost:8099 (`dev/landing-server.ps1`, HttpListener có Range cho video).
- `landing/`: trang tĩnh `index.html` + `assets/` (ảnh webp, video). Cấu hình `landing/site-config.js` (`window.BOSSKIN`: appUrl, contactEmail,
  contactPhone, facebookUrl / tiktokUrl / youtubeUrl, nơi nhận form) dùng chung cho trang trợ giúp (`/help/` đọc `../site-config.js`).
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
- Host chính: Vibe Host `https://bosskin.io.vn` (`landing/Dockerfile`, trợ giúp ở `/help/`, ảnh mạng xã hội ở `/social/`; host duy nhất — Netlify đã gỡ 12/10/2026); app `https://app.bosskin.io.vn`, API `https://api.bosskin.io.vn` (`docs/he-thong/trien-khai.md`). Form dùng thử: có `apiUrl` → API BossKin, không thì Supabase
  (`supabaseUrl` + `supabaseKey`); thiếu cả hai → form báo lỗi. Ô bẫy bot `website`. `appUrl` trống → ẩn nút Đăng nhập.
- Đổi tính năng/giao diện chính → cập nhật nội dung trang (và chụp lại ảnh/video nếu màn hình đổi nhiều).
- Công ty dùng thử trên prod: `tools/demo/seed_test_company.py [API]` — "Công ty test", mã `TEST`, đuôi `@test.com`, 24 NV (gộp dữ liệu chụp ảnh
  seed_demo + seed_help_extra), tắt kiểm tra vị trí / gắn thiết bị. Hỏi email + mật khẩu + mã 2FA system admin và mật khẩu chung tài khoản dùng thử;
  chỉ thêm công ty mới, đã có mã TEST / đuôi test.com thì dừng. Đổi API mà script hỏng → sửa cùng seed_demo (quy tắc 2).
  Xoá hẳn công ty TEST để tạo lại: `tools/demo/clear_test_company.sql` (chủ dự án tự chạy, sao lưu trước; khoá ngoại bật, một transaction,
  chỉ dữ liệu company TEST; không xoá file tài liệu trong kho). Thêm bảng mới có company_id / employee_id / user_id → thêm vào script này.
- Tài liệu in đi sale `docs/in-an/` (poster A3, tờ giới thiệu A4 2 mặt, phiếu đăng ký A4, kịch bản bán hàng `kich-ban-ban-hang.md` → PDF + docx): HTML + `build.py` (Playwright) → `pdf/*.pdf`
  (commit PDF), ảnh từ `landing/assets/`, font Be Vietnam Pro nhúng sẵn. Đổi liên hệ / tính năng chính → sửa cả ở đây (README trong thư mục).

## Tài liệu hệ thống & trang trợ giúp (10/2026)
- `docs/he-thong/`: tài liệu kỹ thuật (kiến trúc, phân quyền, nghiệp vụ, bảo mật, triển khai). `api.md`, `csdl.md`, `quyen.md` **tự sinh**
  — không sửa tay: `MYSQL_CMD="docker exec -i <container> mysql -uroot -p<pw> bosskin" python3 tools/docs/gen_he_thong.py`
  (DB thử đã migrate hết, không dùng DB dev). `--check` (không cần DB) báo `api.md` lệch controller / `csdl.md` cũ hơn migration mới nhất.
  Mục "Kiểm tra đồng bộ" ở `quyen.md` phải ✔ (mã quyền trong code đều có trong bảng `permissions` và ngược lại).
- `help/`: trang trợ giúp tĩnh cho người dùng (22 trang theo vai trò, ~90 ảnh). Nội dung `help/src/NN-<slug>.md` → `python3 help/tools/build_help.py`
  → `help/*.html` (commit cả HTML). Host cùng trang giới thiệu ở `/help/`: image Docker (`landing/Dockerfile`) lấy `help/*.html` + `help/img` từ `main` lúc build; trang giới thiệu có link "Trợ giúp" ở menu và chân trang. Ảnh chụp bằng `help/tools/capture.py` trên môi trường thử riêng có dữ liệu "Nội thất An Phát"
  (`landing/video/seed_demo.py` + `help/tools/seed_help_extra.py`). Hướng dẫn: `help/README.md`.
- SEO: `build_help.py` gắn canonical cho trang trợ giúp và sinh `landing/sitemap.xml` (không sửa tay); `landing/robots.txt` trỏ tới sitemap;
  kiểm `tools/ci/check_sitemap.py` (CI `site-check.yml`). Thêm trang công khai mới ở `landing/` → thêm vào `write_sitemap` + canonical.
- Đổi màn hình / luồng → sửa trang trợ giúp tương ứng (biến lương, tên nút, bước) và chụp lại chương đó trong cùng đợt.

