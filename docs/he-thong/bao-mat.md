# Bảo mật

## Xác thực

| Hạng mục | Cách làm | Ở đâu |
|---|---|---|
| Mật khẩu | BCrypt; tối thiểu 8 ký tự, có chữ và số. Mật khẩu do người khác đặt (tạo NV, đặt lại, nhập Excel) → `must_change_password`, bắt đổi ở lần đăng nhập đầu | `PasswordPolicy`, `AuthService` |
| Chống dò mật khẩu | Sai 5 lần trong 15 phút → khoá đăng nhập tài khoản đó 15 phút (`app.security.login.*`) | `LoginAttemptService` |
| Access token | JWT ký HS (`JWT_SECRET` ≥ 32 byte, không có mặc định — thiếu thì app không chạy), sống 30 phút | `JwtUtil` |
| Refresh token | 7 ngày, mỗi phiên một dòng `user_sessions` (jti, thiết bị) — đăng xuất / khoá tài khoản / đặt lại mật khẩu thu hồi được | `AuthService` |
| 2FA (TOTP) | Tuỳ chọn cho người dùng công ty; quản trị hệ thống **bắt buộc**; quản trị hệ thống có thể bắt buộc cho quản trị của một công ty (`companies.require_admin_2fa`). Đăng nhập trả `challengeToken` 5 phút thay cho token thật; 8 mã dự phòng băm BCrypt, dùng một lần | `Totp`, `TwoFactorService` |
| Token quản trị hệ thống | Chuỗi lọc riêng `/admin/**`, vai trò `SYSTEM_ADMIN`; token công ty không vào được và ngược lại | `SecurityConfig` |

## Chấm công

- **Vị trí**: backend tự tính khoảng cách (haversine) tới toạ độ nhân viên / phòng / công ty, không tin cờ "trong vùng" từ client; chặn vị trí giả lập (`error.attendance.mock_location`).
- **Gắn thiết bị** (bật trong cài đặt công ty): lần chấm đầu gắn mã thiết bị vào nhân viên; máy khác bị chặn đến khi nhân sự gỡ.
- **Khung giờ**: chỉ chấm trong khoảng cho phép quanh giờ ca.

## Dữ liệu

- **Tách công ty**: mọi truy vấn lọc theo `company_id` của người gọi; đối tượng lấy theo id luôn kiểm cùng công ty.
- **Phạm vi phòng ban**: cấu hình lỗi thu về "chỉ bản thân", không mở toàn công ty ([phân quyền](phan-quyen.md#phạm-vi-phòng-ban)).
- **Dữ liệu nhạy cảm** (CCCD, tài khoản NH, MST, sổ BHXH): che `****1234` nếu thiếu `EMPLOYEE_SENSITIVE_VIEW`; xuất Excel cũng che.
- **Tài liệu nhân sự**: lưu riêng tư (S3 `documents/` không công khai); chỉ cấp link ký tạm 300 giây, mỗi lần cấp ghi nhật ký.
- **Lỗi**: không trả stacktrace / SQL / thông điệp nội bộ — chỉ mã lỗi + mã request.
- **Không tự duyệt**: phiếu lương, đơn của chính mình; không tự sửa quyền của mình (`GrantGuard`).
- **Xoá**: phần lớn là xoá mềm (`deleted`); dữ liệu đã chốt (kỳ công khoá, phiếu lương đã duyệt) không sửa được.

## Nhật ký

`audit_logs` chỉ ghi thêm, gồm: thao tác công / kỳ công, lương, vai trò / quyền / phạm vi, tài khoản (khoá, đặt lại mật khẩu, xuất mật khẩu tạm,
2FA, thiết bị), hợp đồng, người phụ thuộc, tài liệu (kể cả xem), hồ sơ, quá trình công tác, lịch, ngày lễ, thông số thuế, quản trị hệ thống
và đăng nhập thay. Mỗi dòng có người làm, thời điểm, đối tượng, giá trị trước → sau.

## Mạng và bí mật

- CORS chỉ cho origin trong `CORS_ALLOWED_ORIGINS`.
- Form dùng thử công khai giới hạn theo IP (`TRIAL_MAX_PER_IP_HOUR`); proxy bản đồ giới hạn số ô / phút / người dùng.
- Bí mật (DB, JWT, khoá Firebase, Supabase) chỉ ở biến môi trường / Secrets Manager, không có trong git. Prod: RDS không mở Internet,
  bắt buộc TLS, mã hoá; S3 mã hoá, chặn công khai trừ ảnh đại diện / ảnh công ty.
- Chỉ `/actuator/health` công khai.
- Quy trình khi lộ bí mật, đổi JWT, khoá tài khoản: [runbook](../runbook.md) mục 7 và 11.
