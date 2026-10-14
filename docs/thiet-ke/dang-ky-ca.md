# Thiết kế: Đăng ký lịch làm việc (nhân viên tự đăng ký ngày + khung giờ)

Trạng thái: **bản thiết kế, chưa làm**. Ngày viết 14/10/2026. Hình mẫu giao diện: `dang-ky-ca/*.png` (nguồn `dang-ky-ca/mockup.html`).

## 1. Mục tiêu

Nhân viên tự đăng ký **ngày nào làm** và **làm từ mấy giờ đến mấy giờ** trong một khoảng thời gian quản lý mở ra
(một tuần, nửa tháng, một tháng… tuỳ ý). Quản lý **mở / đóng** đợt đăng ký, xem ai rảnh khung nào, rồi duyệt để đăng ký
thành **lịch làm việc chính thức** (phân ca) — từ đó chấm công và tính lương chạy như bình thường.

Hợp với: cửa hàng, quán, nhà hàng, kho có nhân viên bán thời gian, sinh viên làm thêm — lịch mỗi người mỗi khác, đổi theo tuần.

Công ty **bật / tắt** chức năng ở Cài đặt công ty. Tắt (mặc định) → ẩn menu, ẩn tab, API trả `403 error.shift_registration.disabled`.

## 2. Khái niệm

| Khái niệm | Ý nghĩa |
|---|---|
| **Đợt đăng ký** | Một khoảng ngày `từ ngày – đến ngày` (bất kỳ, tối đa 62 ngày) cho một số phòng ban, có hạn chót. Trạng thái: Nháp → **Đang mở** ⇄ **Đã đóng** → Đã xếp lịch (hoặc Huỷ). |
| **Đăng ký** | Một khung giờ nhân viên đăng ký trong một ngày của đợt: `ngày, giờ bắt đầu, giờ kết thúc, ghi chú`. Một ngày tối đa 2 khung (vd. sáng + tối). Trạng thái: Chờ duyệt → Đã duyệt / Từ chối; nhân viên tự huỷ khi đợt còn mở. |
| **Xếp lịch** | Quản lý bấm "Xếp lịch từ đăng ký": mỗi đăng ký đã duyệt thành một dòng phân ca (`shift_assignments`) giờ tuỳ chỉnh (`custom_start/end_time` — đã có sẵn), hoặc gắn vào ca có sẵn nếu quản lý chọn. |

## 3. Luồng

```
Quản lý                         Nhân viên                         Hệ thống
───────                         ─────────                         ────────
Tạo đợt (ngày, phòng ban,  ──►
 hạn chót, giới hạn)
Bấm "Mở đăng ký"           ──►  nhận thông báo                    gửi FCM tới NV trong phạm vi
                                chọn ngày + khung giờ, gửi
                                sửa / huỷ khi đợt còn mở           nhắc 24 giờ trước hạn chót
(có thể Đóng / Mở lại bất kỳ lúc nào)                              tự đóng khi tới hạn chót
Xem lưới: người × ngày,
 biểu đồ số người theo giờ
Duyệt / sửa giờ / từ chối
Bấm "Xếp lịch từ đăng ký"  ──►  nhận thông báo lịch đã xếp        tạo phân ca, báo dòng bỏ qua
```

Sau khi xếp lịch, mọi thay đổi đi qua chức năng hiện có: sửa phân ca, đổi / nhường ca.

## 4. Quy tắc nghiệp vụ

**Đợt đăng ký**
- Khoảng ngày bất kỳ, `đến ngày ≥ từ ngày`, dài tối đa **62 ngày**; không bắt đầu trong quá khứ; không chồng lên kỳ công đã khoá (`error.shift_registration.period_locked`).
- Phạm vi: chọn phòng ban (gồm phòng con), chỉ trong phạm vi quyền của người tạo.
- Hạn chót (`closes_at`, không bắt buộc): tới giờ thì tự đóng (job mỗi 5 phút). Đóng tay / mở lại được bất kỳ lúc nào trước khi xếp lịch.
- Hai đợt **cùng phòng ban không được chồng ngày** (`error.shift_registration.overlap|<tên đợt>`).
- Tuỳ chọn của đợt (để trống = không giới hạn):
  - khung giờ cho phép (vd. 06:00–23:00) — mặc định lấy giờ ngày công ty `day_start_time–day_end_time`;
  - số giờ tối thiểu / tối đa mỗi khung (vd. 2–10 giờ);
  - số ngày tối thiểu / tối đa mỗi người trong đợt (vd. ít nhất 3 ngày/tuần);
  - số người cần mỗi ngày (chỉ để hiển thị thiếu / đủ, không chặn).
- Duyệt tự động (tuỳ chọn): khi đóng đợt, mọi đăng ký hợp lệ chuyển "Đã duyệt" luôn.

**Đăng ký của nhân viên**
- Chỉ khi công ty bật chức năng, đợt **Đang mở**, nhân viên còn làm và thuộc phòng ban của đợt.
- Ngày trong khoảng của đợt và **chưa qua**; mỗi ngày ≤ **2 khung**, không chồng nhau; `kết thúc > bắt đầu`, hoặc qua đêm
  (kết thúc < bắt đầu, ví dụ 22:00–06:00) nếu công ty bật chế độ ngày / đêm.
- Trong khung giờ cho phép và độ dài cho phép của đợt.
- Ngày đã có đơn nghỉ được duyệt → cho đăng ký nhưng **cảnh báo**; ngày lễ nghỉ → cảnh báo.
- Sửa / huỷ khi đợt còn mở. Đợt đóng → chỉ xem.
- Số ngày tối thiểu: kiểm tra khi nhân viên bấm "Gửi" và khi đóng đợt (báo người còn thiếu cho quản lý, không tự từ chối).

**Duyệt và xếp lịch**
- Quản lý duyệt / từ chối / **sửa giờ** từng đăng ký hoặc chọn nhiều; sửa giờ được ghi lại giờ gốc nhân viên đăng ký.
- Không tự duyệt đăng ký của chính mình (`error.shift_registration.cannot_process_own`), giống các đơn khác.
- Chế độ duyệt 2 bước của công ty (quản lý trực tiếp → nhân sự) **không áp dụng** — người có quyền quản lý đăng ký ca duyệt một lần.
- "Xếp lịch từ đăng ký": chỉ khi đợt đã đóng. Mỗi đăng ký đã duyệt → 1 phân ca giờ tuỳ chỉnh qua `WorkShiftService.validatePlacement`
  (tối đa 4 ca/ngày, không chồng giờ). Ngày đã có phân ca trùng giờ → bỏ qua và báo lại. Chạy lại được (bỏ qua dòng đã xếp).
- Quản lý có thể chọn gắn khung giờ vào **ca có sẵn** (vd. 08:00–12:00 ↔ ca "Sáng") thay vì giờ tuỳ chỉnh — để báo cáo theo ca vẫn đúng.

## 5. Dữ liệu (migration V23)

```sql
ALTER TABLE companies ADD COLUMN shift_registration_enabled tinyint(1) NOT NULL DEFAULT 0;

CREATE TABLE shift_registration_rounds (
  id bigint PK, company_id bigint FK,
  name varchar(100), from_date date, to_date date,
  status enum('DRAFT','OPEN','CLOSED','APPLIED','CANCELLED'),
  opens_at datetime NULL, closes_at datetime NULL,          -- closes_at: hạn chót tự đóng
  earliest_time time NULL, latest_time time NULL,           -- khung giờ cho phép
  min_hours decimal(4,2) NULL, max_hours decimal(4,2) NULL, -- độ dài 1 khung
  min_days int NULL, max_days int NULL,                     -- số ngày / người trong đợt
  needed_per_day int NULL, auto_approve tinyint(1) DEFAULT 0,
  note varchar(500), created_by bigint, applied_at datetime NULL, applied_by bigint NULL,
  deleted tinyint(1), created_at, updated_at
);
CREATE TABLE shift_registration_round_departments (round_id, department_id, PK(round_id, department_id));
CREATE TABLE shift_registrations (
  id bigint PK, company_id bigint, round_id bigint FK, employee_id bigint FK,
  work_date date, start_time time, end_time time,
  original_start_time time NULL, original_end_time time NULL,   -- giờ NV đăng ký nếu quản lý sửa
  shift_id bigint NULL,                                          -- gắn ca có sẵn khi xếp lịch
  status enum('PENDING','APPROVED','REJECTED','CANCELLED'),
  note varchar(255), decided_by bigint NULL, decided_at datetime NULL, decision_note varchar(255),
  assignment_id bigint NULL FK shift_assignments,                -- sau khi xếp lịch
  deleted tinyint(1), created_at, updated_at,
  KEY (round_id, work_date), KEY (employee_id, work_date)
);
```
Thêm quyền vào bảng `permissions` (mục 6) và cấp cho vai trò sẵn có (mục 6). Bổ sung `tools/demo/clear_test_company.sql`
cho 3 bảng mới (quy tắc 2).

## 6. Phân quyền

| Mã quyền | Nghĩa | Phụ thuộc | Cấp sẵn |
|---|---|---|---|
| `SHIFT_REGISTRATION_SELF` | Nhân viên đăng ký lịch của mình | — | vai trò "Nhân viên" mặc định (công ty mới + migration cho vai trò mặc định đang có) |
| `SHIFT_REGISTRATION_MANAGE` | Tạo / mở / đóng đợt, duyệt, xếp lịch | `SHIFT_VIEW` | "Admin" |

Phạm vi phòng ban theo `SHIFT_VIEW` của người quản lý (giống phân ca). Công ty tắt chức năng → mọi API 403 dù có quyền.

## 7. API

| Phương thức | Đường dẫn | Quyền |
|---|---|---|
| GET / POST | `/api/v1/shift-registration-rounds` (lọc `status`, `from`, `to`) | MANAGE |
| GET / PUT / DELETE | `/api/v1/shift-registration-rounds/{id}` (sửa khi Nháp / Đóng; xoá khi Nháp) | MANAGE |
| POST | `/{id}/open`, `/{id}/close`, `/{id}/cancel` | MANAGE |
| GET | `/{id}/registrations` (lưới người × ngày + tổng theo ngày / giờ) | MANAGE |
| POST | `/{id}/registrations/decide` `{ids, action: APPROVE|REJECT, note}` | MANAGE |
| PATCH | `/registrations/{id}` `{startTime, endTime, shiftId?}` (sửa giờ) | MANAGE |
| POST | `/{id}/apply` → `{created, skipped:[{employee, date, reason}]}` | MANAGE |
| GET | `/{id}/export` (Excel: người × ngày, ô = khung giờ + trạng thái) | MANAGE |
| GET | `/api/v1/shift-registrations/self/rounds` (đợt đang mở / gần đây của tôi) | SELF |
| GET / PUT | `/api/v1/shift-registrations/self/rounds/{id}` (đọc / ghi cả lịch của tôi trong đợt) | SELF |

Cài đặt công ty: `CompanySettingDTO` thêm `shiftRegistration: { enabled }`; lưu qua `PUT /api/v1/company-settings`.
Mã lỗi mới (`error.shift_registration.*`): `disabled`, `not_found`, `not_open`, `not_in_scope`, `invalid_time`, `outside_window`,
`too_short|giờ`, `too_long|giờ`, `too_many_slots`, `overlap_slot`, `max_days|n`, `past_date`, `overlap|tên đợt`,
`period_locked`, `range_too_long`, `cannot_process_own`, `not_closed` — dịch vi + en ở `error_utils.dart` (CI kiểm).

Nhật ký: `SHIFT_REG_ROUND_CREATE / UPDATE / OPEN / CLOSE / CANCEL / APPLY`, `SHIFT_REG_DECIDE`, `SHIFT_REG_EDIT_TIME`.
Báo đẩy: mở đợt (NV trong phạm vi), 24 giờ trước hạn chót (NV chưa đăng ký), xếp lịch xong (NV có lịch), đợt tự đóng (người tạo đợt).

## 8. Giao diện

**Cài đặt công ty → Chung**: công tắc "Cho nhân viên đăng ký lịch làm việc" (cần quyền sửa cài đặt).

**Quản lý — Ca làm → tab "Đăng ký lịch"** (ẩn khi tắt chức năng hoặc thiếu quyền), hình `dang-ky-ca/quan-ly-danh-sach.png`, `quan-ly-chi-tiet.png`:
- Danh sách đợt: tên, khoảng ngày, phòng ban, hạn chót, trạng thái, số người đã đăng ký / tổng; nút **Mở** / **Đóng** ngay trên dòng.
- Tạo đợt: chọn nhanh "Tuần sau" / "Tháng sau" hoặc chọn từ ngày – đến ngày; phòng ban (`DepartmentPickerField`); hạn chót; giới hạn (mở rộng).
- Chi tiết đợt: lưới người × ngày, mỗi ô là khung giờ (màu theo trạng thái), hàng cuối "số người / cần"; biểu đồ số người theo giờ của ngày đang chọn
  để thấy giờ nào thiếu người; chọn nhiều ô → Duyệt / Từ chối; bấm ô → sửa giờ / gắn ca có sẵn; nút **Xếp lịch từ đăng ký**, **Xuất Excel**.

**Nhân viên — menu "Đăng ký lịch"** (điện thoại trước), hình `dang-ky-ca/nhan-vien.png`:
- Đợt đang mở + hạn chót đếm ngược; danh sách ngày trong đợt, mỗi ngày bật "Làm" rồi chọn giờ bắt đầu – kết thúc
  (nút nhanh: Cả ngày / Sáng / Chiều / Tối theo khung đợt), thêm khung thứ 2.
- Thanh dưới: "Đã chọn 4 ngày · 28 giờ" + nút **Gửi đăng ký**; sau khi gửi vẫn sửa được tới khi đóng.
- Đợt đã đóng / đã xếp: xem trạng thái từng ngày (Đã duyệt / Từ chối / Đã xếp lịch).

Chuỗi hiển thị qua l10n (vi + en), màu theo `AppTheme`, dùng lại `StatusBadge`, `DateField`, `DepartmentPickerField`, `EmptyState`, `PermissionGuard`.

## 9. Kiểm thử (`ShiftRegistrationTest`)

1. Công ty tắt → mọi API 403 `disabled`; bật → dùng được.
2. NV đăng ký khi đợt Nháp / Đóng → `not_open`; ngoài phòng ban → `not_in_scope`; ngày đã qua → `past_date`.
3. Khung giờ: kết thúc ≤ bắt đầu (không bật ngày / đêm) → `invalid_time`; 3 khung / ngày → `too_many_slots`; chồng nhau → `overlap_slot`; ngoài khung đợt / quá ngắn / quá dài.
4. Đóng / mở lại; tự đóng khi qua hạn chót (đồng hồ test).
5. Hai đợt cùng phòng ban chồng ngày → `overlap`; đợt chạm kỳ công đã khoá → `period_locked`.
6. Duyệt, sửa giờ (giữ giờ gốc), từ chối; không tự duyệt của mình.
7. Xếp lịch: tạo phân ca giờ tuỳ chỉnh đúng ngày giờ; gắn ca có sẵn; trùng phân ca có sẵn → bỏ qua và báo; chạy lại không tạo trùng; chấm công + bảng công nhận phân ca mới.
8. Phạm vi quản lý: người quản lý phòng A không thấy / duyệt đăng ký phòng B.
9. FE: `flutter test` cho hàm kiểm khung giờ (chồng nhau, qua đêm).

## 10. Kế hoạch triển khai

| Bước | Việc | Ước tính |
|---|---|---|
| 1 | V23 + entity / repository + công tắc công ty + quyền | 0,5 ngày |
| 2 | Service: đợt (tạo, mở, đóng, tự đóng), đăng ký của NV, kiểm tra; API + nhật ký + mã lỗi | 1,5 ngày |
| 3 | Duyệt / sửa giờ / xếp lịch sang phân ca; xuất Excel; báo đẩy | 1 ngày |
| 4 | Test backend (mục 9) | 0,5 ngày |
| 5 | FE quản lý: tab Đăng ký lịch (danh sách, tạo, lưới, biểu đồ theo giờ, xếp lịch) + công tắc cài đặt | 1,5 ngày |
| 6 | FE nhân viên: màn đăng ký trên điện thoại | 1 ngày |
| 7 | Tài liệu: `docs/he-thong` (sinh lại api/csdl/quyen), trang trợ giúp (ca làm + nhân viên, chụp ảnh), CLAUDE.md, seed TH / Công ty test thêm 1 đợt mẫu, `clear_test_company.sql` | 0,5 ngày |

Tổng khoảng **6,5 ngày** làm việc. Làm theo thứ tự trên; mỗi bước đẩy lên `main` khi test xanh.

## 11. Cần chủ dự án chốt

1. **Ai quản lý đợt**: theo quyền `SHIFT_REGISTRATION_MANAGE` + phạm vi phòng ban (đề xuất) — hay cho cả quản lý trực tiếp tự mở cho nhóm mình?
2. **Duyệt tự động** khi đóng đợt có nên là mặc định không (đề xuất: tắt, quản lý duyệt tay).
3. **Đăng ký là ràng buộc hay nguyện vọng**: thiết kế này coi là nguyện vọng — quản lý có thể sửa giờ / từ chối. Có cần NV xác nhận lại khi quản lý sửa giờ không (đề xuất: chỉ báo đẩy, không cần xác nhận)?
4. Số khung tối đa mỗi ngày: 2 có đủ không?
