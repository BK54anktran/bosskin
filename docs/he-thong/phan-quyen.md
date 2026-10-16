# Phân quyền

## Ba lớp kiểm tra

1. **Mã quyền** — người dùng có quyền làm loại thao tác này không (`LEAVE_APPROVE`, `PAYROLL_CREATE`…). Danh mục: [quyen.md](quyen.md).
2. **Phạm vi phòng ban** — với các quyền có phạm vi, người dùng thao tác trên nhân viên của những phòng nào.
3. **Quy tắc riêng của nghiệp vụ** — chính chủ (xem phiếu lương của mình), không tự duyệt (đơn / phiếu lương của chính mình),
   quản lý trực tiếp (duyệt bước 1), kỳ công đã khoá, dữ liệu nhạy cảm bị che.

## Tính năng theo công ty (V26, thay gói chức năng V24)

System admin bật / tắt **33 tính năng** cho từng công ty (`core/CompanyFeatures`, cột `companies.disabled_features` = danh sách mã TẮT,
NULL = bật hết; có hiệu lực ngay, không lập lịch). Phần nền — nhân viên, phòng ban, phân quyền, cài đặt, tổng quan, nhật ký, bảo mật — luôn có.
Danh mục + lý do chia: `docs/thiet-ke/goi-chuc-nang.md`. Tiền tính ngoài app (app chỉ giữ công tắc).
- **Danh mục** theo nhóm: Chấm công (`ATT_SHEET`, `ATT_SELF`, `ATT_GEOFENCE`, `ATT_DEVICE`, `ATT_NOSHIFT`, `ATT_REQUEST`), Ca làm (`SHIFT_BASIC`,
  `SHIFT_ADVANCED`, `SHIFT_ROTATION`, `SHIFT_SWAP`, `SHIFT_REGISTRATION`, `SHIFT_REMINDER`), Lịch (`CAL_WORKCAL`, `CAL_HOLIDAY`), Nghỉ phép
  (`LEAVE_BASIC`, `LEAVE_BALANCE`, `LEAVE_ACCRUAL`), Tính lương (`PAY_BASIC`, `PAY_FORMULA`, `PAY_TAX_INS`, `PAY_DEPENDENT`, `PAY_EMPLOYER_COST`),
  Nhân sự (`HR_CONTRACT`, `HR_CONTRACT_ALERT`, `HR_DOCUMENT`, `HR_DOCUMENT_ALERT`, `HR_ORGCHART`, `HR_JOBHISTORY`, `HR_MANAGER_APPROVAL`),
  Báo cáo & dữ liệu (`RPT_OVERVIEW`, `RPT_PAYROLL`, `RPT_INSURANCE`, `DATA_EXCEL`). Mỗi tính năng có "cần": bật con phải bật cha, tắt cha tắt con
  (`PAY_BASIC` → `PAY_FORMULA` / `PAY_TAX_INS` → `PAY_DEPENDENT` → `RPT_INSURANCE`…). Ràng buộc riêng: tự chấm công (`ATT_SELF`) cần `SHIFT_BASIC` **hoặc** `ATT_NOSHIFT`.
- **Ba lớp chặn**: (1) `User.getPermissions()` bỏ mã quyền thuộc tính năng tắt (`CompanyFeatures.featureOfPermission`: mã riêng của tính năng như
  `SHIFT_REGISTRATION_*`, `LEAVE_ACCRUAL_*`; quyền chung như `ATTENDANCE_SELF` thuộc tính năng gốc của gói); (2) `FeatureRouteInterceptor` +
  bảng `core/FeatureRoutes` (đường dẫn → tính năng) trả 403 `error.company.feature_disabled` — một chỗ duy nhất cho mọi API; (3) hành vi trong nghiệp vụ /
  job nền kiểm `CompanyFeatures.require(user|company, F)` / `User.isFeatureDisabled(F)`. `JwtAuthFilter` nạp sẵn tập tắt vào user; đăng nhập thay của system admin cũng bị chặn.
- **Tương thích V24**: đăng nhập / làm mới token trả `features` (mới) và `modules` (7 gói cũ = tính năng gốc còn bật) vì app điện thoại đã cài chỉ đọc `modules`;
  `PUT /admin/companies/{id}` nhận `features` (ưu tiên) hoặc `modules` (cũ). Migration V26 chuyển đúng: gói cũ tắt ⇒ mọi tính năng con tắt, rồi bỏ `disabled_modules`.
- **Màn Phân quyền** (`GET /roles/permissions`, dùng cho cả hộp vai trò lẫn quyền riêng của người dùng) **không liệt kê quyền của tính năng đã tắt**. Khi lưu vai trò /
  quyền riêng / phạm vi phòng ban, backend **giữ nguyên** những quyền (và phạm vi) đó đang có (`PermissionConsistencyService.keepHiddenFeaturePermissions` / `keepHiddenFeatureScopes`),
  nên bật lại tính năng thì quyền đã cấp dùng được ngay. Quyền dùng chung kiểu `ATTENDANCE_SELF` thuộc tính năng gốc của gói nên chỉ ẩn khi gói gốc tắt.
- **Cài đặt của tính năng tắt = tắt** (`Company.locationCheckActive()`, `deviceBindingActive()`, `checkInWithoutShiftActive()`, `shiftRegistrationActive()`,
  `effectiveApprovalMode()`): màn Cài đặt ẩn mục thì backend không áp giá trị cũ. Lương: `PAY_TAX_INS` tắt → không trừ thuế / BH, `PAY_DEPENDENT` tắt → 0 người phụ thuộc,
  `PAY_EMPLOYER_COST` tắt → BH công ty đóng = 0. Job: nhắc ca / chấm công (`SHIFT_REMINDER`), cộng phép (`LEAVE_ACCRUAL`), báo hợp đồng / tài liệu (`HR_*_ALERT`).
  Bảng đầy đủ + phần còn lại: `docs/thiet-ke/goi-chuc-nang.md`.
- Sửa ở `PUT /admin/companies/{id}` `{features: [...]}` (tính năng BẬT; không gửi = giữ), nhật ký `COMPANY_FEATURES` (`turnedOn` / `turnedOff`).
  Thêm tính năng mới → thêm vào `CompanyFeatures.CATALOG` + `company_feature_utils.dart` + nhãn vi / en; `tools/ci/check_features.py` kiểm hai bên khớp.
  Test: `CompanyFeaturesCatalogTest`, `CompanyFeaturesTest`, `CompanyModulesTest` (tương thích).

## Vai trò và quyền

- Vai trò (`roles`) thuộc từng công ty, gom một tập quyền (`role_permissions`) và phạm vi cho từng quyền (`role_permission_dept_scopes`).
  Người dùng có thể có nhiều vai trò (`user_roles`); quyền là hợp của các vai trò.
- Tạo công ty sinh sẵn hai vai trò: **Admin** (mọi quyền) và **Nhân viên** (mặc định cho nhân viên mới:
  `ATTENDANCE_VIEW`, `ATTENDANCE_SELF`, `LEAVE_VIEW`, `LEAVE_REQUEST_CREATE`, phạm vi "chỉ bản thân"). Các vai trò khác (Nhân sự, Kế toán,
  Quản lý phòng…) do công ty tự tạo ở màn Phân quyền.
- **Quyền trực tiếp** cho từng người (`user_permissions` + `user_permission_dept_scopes`): khi người dùng có bất kỳ quyền trực tiếp nào
  thuộc một **module**, toàn bộ quyền của module đó lấy theo phần trực tiếp, bỏ qua phần từ vai trò (`User.getPermissions()`). Dùng để
  thu hẹp hoặc nới riêng một người mà không tạo vai trò mới.
- **Quyền phụ thuộc** (`permissions.required_rule`): vd. `CONTRACT_EDIT` cần `CONTRACT_VIEW`. Màn Phân quyền tự tích; khi lưu,
  `PermissionConsistencyService` chuẩn hoá danh sách mã: bỏ mã không tồn tại, có quyền thao tác của module nào thì tự thêm quyền `…_VIEW`
  của module đó.
- **Admin mặc định bị khoá (V30)**: vai trò Admin sinh sẵn khi tạo công ty có `roles.is_system = 1` → người dùng công ty (kể cả Admin) không sửa quyền / đổi tên / xoá được (`403 error.role.system_locked`), chỉ system admin (impersonate). Tài khoản admin đầu tiên của công ty (id nhỏ nhất) không bị đổi vai trò / quyền riêng / phạm vi / khoá bởi người khác (`403 error.user.first_admin_locked`). Admin vẫn tạo vai trò khác và gán Admin cho người khác bình thường. Test: `SystemRoleLockTest`, `GrantGuardTest`. Công ty cũ: migration V30 đánh dấu các vai trò của tài khoản đầu tiên.
- `GrantGuard` chặn leo thang quyền: không tự sửa vai trò / quyền / phạm vi của chính mình, chỉ cấp được quyền mình đang có (quyền của tính năng công ty đang tắt không tính — vai trò Admin vẫn giữ đủ quyền nên Admin vẫn cấp lại được vai trò Admin; test `GrantGuardTest`).

> Ghi chú: các tên vai trò cố định cũ (`ADMIN`, `HR_MANAGER`, `HR_STAFF`, `EMPLOYEE`) không còn dùng trong code; mọi kiểm tra đi qua mã quyền.

## Phạm vi phòng ban

Lưu dạng danh sách id phòng ban cho từng (vai trò hoặc người dùng, mã quyền). Giá trị đặc biệt:

| Giá trị | Ý nghĩa |
|---|---|
| (không cấu hình) | Toàn công ty |
| id phòng > 0 | Phòng đó **và mọi phòng con** |
| `-1` | Chỉ bản thân |
| `-2` | Phòng của tôi |
| `-3` | Phòng của tôi và phòng con |

`DeptScopeService.resolvedScopes(userId, code)` trả tập phòng đã mở rộng (rỗng = toàn công ty). Nếu cấu hình có nhưng không phân giải được
phòng nào (vd. "phòng của tôi" mà tài khoản chưa gắn nhân viên) thì thu về "chỉ bản thân" — không bao giờ mở thành toàn công ty.
`requireValidScopeIds` chặn gửi id phòng của công ty khác.

## Quản lý trực tiếp và duyệt 2 bước

`employees.manager_id` (đổi qua quá trình công tác, loại `MANAGER_CHANGE`). Cài đặt công ty `approval_mode`:

- `PERMISSION` (mặc định): ai có quyền duyệt + đúng phạm vi thì duyệt.
- `MANAGER_THEN_HR`: đơn nghỉ, yêu cầu chấm công, đổi ca của nhân viên có quản lý trực tiếp đi qua **bước 1** quản lý (màn *Duyệt cho nhóm*,
  `/api/v1/team-approvals`, không cần mã quyền) rồi **bước 2** người có quyền duyệt. Quản lý từ chối → kết thúc, hoàn phép.

Quyền sửa / duyệt / xoá kế thừa phạm vi của quyền xem tương ứng (`ATTENDANCE_VIEW` cho công, `SHIFT_VIEW` cho đổi ca):
- Xoá công (`DELETE /attendances/{id}`): cần `ATTENDANCE_MANAGE` **và** dòng công nằm trong phạm vi xem; ngoài phạm vi trả 403.
- Duyệt đổi ca (`SHIFT_SWAP_APPROVE`): người duyệt chỉ thấy / duyệt / từ chối đơn mà cả người xin và người nhận thuộc phạm vi `SHIFT_VIEW` của mình
  (đơn mà chính họ là người xin hoặc người nhận vẫn thấy được; tự duyệt vẫn bị chặn).
- Báo cáo tổng quan năm (`/reports/yearly-overview`) gồm số liệu lương, nhân sự và nghỉ phép nên cần đủ `PAYROLL_VIEW`, `EMPLOYEE_VIEW`, `LEAVE_VIEW`
  (công ty tắt tính năng nghỉ phép thì mất `LEAVE_VIEW` nên không xuất được); app ẩn báo cáo này khi thiếu một trong ba.
- Danh sách phòng ban dạng phẳng (`/departments/flat?permission=X_VIEW`) chỉ cần quyền `X_VIEW` đó (không đòi `DEPARTMENT_VIEW`);
  danh sách chọn nhân viên ở bảng công (`/attendances/employees`) theo phạm vi `ATTENDANCE_VIEW`, không đòi `EMPLOYEE_VIEW`.
- Màn Chấm công ẩn nút Sửa / Xoá / Sửa hàng loạt khi thiếu `ATTENDANCE_MANAGE`, nút Duyệt / Bỏ duyệt khi thiếu `ATTENDANCE_APPROVE`.

## Dữ liệu nhạy cảm

CCCD, số tài khoản ngân hàng, mã số thuế, số sổ BHXH (và của người phụ thuộc) chỉ trả nguyên văn cho người có `EMPLOYEE_SENSITIVE_VIEW`;
người khác nhận dạng che `****1234` (`core/SensitiveData`). Khi lưu, giá trị che gửi lại được hiểu là "không đổi".
Tỷ lệ bảo hiểm công ty đóng (`payroll.employer*Percent` ở `GET /company-settings`) chỉ trả cho người có `PAYROLL_VIEW` hoặc `COMPANY_SETTING_MANAGE`.

## Quản trị hệ thống

Tài khoản ở bảng `system_admins`, đăng nhập `/admin/auth/login`, **bắt buộc 2FA**, token riêng chỉ dùng cho `/admin/**`. Không có mã quyền
chi tiết — mọi quản trị viên hệ thống ngang quyền; luôn còn ít nhất một người hoạt động.

## Thêm quyền mới (cho người phát triển)

1. Migration mới: `INSERT INTO permissions (code, description, module, required_rule) …` và gán cho vai trò Admin của mọi công ty
   (`INSERT INTO role_permissions … SELECT r.id … FROM roles r WHERE r.name='Admin'`) — xem V16, V18.
2. Kiểm ở controller bằng `requirePermission`; nếu có phạm vi, dùng `DeptScopeService` ở service.
3. Thêm vào `nav_access.dart` (FE) nếu điều khiển mục menu; thêm mô tả hiển thị ở màn Phân quyền (l10n).
4. Sinh lại [quyen.md](quyen.md) và [api.md](api.md); mục "Kiểm tra đồng bộ" phải báo ✔.
