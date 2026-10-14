# Thiết kế: Đăng ký lịch làm việc (nhân viên tự đăng ký ngày + khung giờ)

Trạng thái: **đã làm (V23, 14/10/2026)**. Hình mẫu giao diện: `dang-ky-ca/*.png` theo style bộ thiết kế BossKin (nguồn `dang-ky-ca/mockup.html`,
chụp lại bằng `dang-ky-ca/render.py`); artboard cho artifact thiết kế ở `dang-ky-ca/artboards/`. Hình mẫu vẽ trước khi chốt — bản làm thật
khác ở: không có nút "Xếp lịch từ đăng ký" (duyệt theo ngày tạo phân ca luôn), nhân viên chọn ca có sẵn / giờ tuỳ chỉnh / rảnh cả ngày.

## 1. Mục tiêu

Nhân viên tự đăng ký **ngày nào làm** và **làm ca nào / từ mấy giờ đến mấy giờ** trong một khoảng thời gian quản lý mở ra
(một tuần, nửa tháng, một tháng… tuỳ ý). Quản lý **mở / đóng** đợt, xem ai rảnh khung nào, rồi **duyệt theo từng ngày** để tạo phân ca nhanh.
Quản lý vẫn xếp ca bình thường ở Phân công ca; duyệt đăng ký chỉ là cách tạo phân ca nhanh.

Công ty **bật / tắt** ở Cài đặt công ty (mặc định tắt) → ẩn menu, ẩn tab, API trả `403 error.shift_registration.disabled`.

## 2. Chủ dự án đã chốt (14/10/2026)

1. Quản lý đợt theo quyền `SHIFT_REGISTRATION_MANAGE` + phạm vi phòng ban (không cho quản lý trực tiếp tự mở).
2. Không tự duyệt khi đóng đợt. Đăng ký chỉ là đăng ký; quản lý duyệt **theo ngày** (nút "Duyệt" trên từng cột ngày) để tạo phân ca nhanh.
3. Nhân viên đăng ký theo **ca có sẵn**, **giờ tuỳ chỉnh** (như hộp chọn ca ở Phân công ca) hoặc **rảnh cả ngày — xếp sao cũng được**.
4. Quản lý đổi giờ khi duyệt: chỉ báo (không cần nhân viên xác nhận). Tối đa **2 khung / ngày**.

## 3. Luồng

```
Quản lý                         Nhân viên                         Hệ thống
───────                         ─────────                         ────────
Tạo đợt (ngày, phòng ban,  ──►
 hạn chót, giới hạn)
Mở đăng ký                 ──►  nhận thông báo                    FCM tới NV thuộc phòng ban của đợt
                                mỗi ngày: ca / giờ / rảnh cả ngày
                                gửi, sửa tới khi đợt đóng          tự đóng khi tới hạn chót
(Đóng / Mở lại bất kỳ lúc nào)
Xem lưới người × ngày, số người theo giờ
Duyệt cả ngày (chọn ca cho người rảnh cả ngày)                     tạo phân ca, báo dòng bỏ qua
 hoặc bấm từng ô: duyệt / đổi ca / đổi giờ / từ chối
```

## 4. Quy tắc nghiệp vụ

**Đợt**
- `đến ngày ≥ từ ngày`, dài tối đa **62 ngày**, chưa kết thúc. Phòng ban (gồm phòng con) trong phạm vi `SHIFT_VIEW` của người tạo.
- Hai đợt có chung phòng ban **không được chồng ngày** (`error.shift_registration.overlap|<tên đợt>`).
- Trạng thái: Nháp → Đang mở ⇄ Đã đóng. Hạn chót (`closes_at`) tới thì tự đóng (job 5 phút); mở lại khi hạn chót đã qua → bỏ hạn chót.
- Giới hạn (để trống = không giới hạn): khung giờ cho phép, số giờ tối thiểu / tối đa mỗi khung (chỉ áp cho giờ tuỳ chỉnh),
  số ngày tối thiểu mỗi người (kiểm khi gửi), số người cần mỗi ngày (chỉ để hiện thiếu / đủ).
- Xoá đợt: khi chưa có đăng ký nào được duyệt (`has_approved`).

**Đăng ký của nhân viên**
- Công ty bật, đợt Đang mở, nhân viên còn làm và thuộc phòng ban của đợt (`not_open`, `not_in_scope`).
- Mỗi ngày ≤ 2 khung, không chồng giờ (qua đêm: kết thúc trước bắt đầu); "rảnh cả ngày" đứng một mình.
- Gửi = ghi cả lịch trong đợt: thay mọi khung chưa duyệt của ngày chưa qua; ngày đã có khung được duyệt giữ nguyên; ngày đã qua không thêm được.

**Duyệt**
- Theo ngày: mọi khung chờ của ngày đó trong phạm vi người duyệt → `WorkShiftService.assign` (ca có sẵn → gắn ca; giờ tuỳ chỉnh → phân ca giờ tuỳ chỉnh;
  rảnh cả ngày → ca quản lý chọn, không chọn thì bỏ qua và báo). Mỗi khung một giao dịch: trùng phân ca có sẵn, quá 4 ca/ngày, kỳ đã khoá… → bỏ qua, trả lý do.
- Từng ô: duyệt theo đăng ký / đổi sang ca khác / giờ khác, hoặc từ chối.
- Ô đã duyệt hiện **ca / giờ thực tế của phân ca đã tạo** (`assignedShiftCode`, `assignedStartTime/EndTime`), di chuột xem bản đăng ký gốc;
  biểu đồ số người theo giờ cũng dùng giờ đã xếp.
- Không tự duyệt / từ chối đăng ký của chính mình (`cannot_process_own`). Chế độ duyệt 2 bước (quản lý trực tiếp → nhân sự) không áp dụng.

## 5. Dữ liệu (V23)

- `companies.shift_registration_enabled`.
- `shift_registration_rounds` (tên, từ / đến ngày, `status` DRAFT | OPEN | CLOSED, `closes_at`, `earliest_time` / `latest_time`, `min_hours` / `max_hours`,
  `min_days`, `needed_per_day`, ghi chú, người tạo, xoá mềm) + `shift_registration_round_departments`.
- `shift_registrations` (đợt, nhân viên, ngày, `kind` SHIFT | CUSTOM | ANY, `shift_id`, `start_time` / `end_time` (SHIFT: giờ chụp từ ca),
  `status` PENDING | APPROVED | REJECTED, `assignment_id` phân ca đã tạo, người / lúc duyệt, xoá mềm).
- Quyền `SHIFT_REGISTRATION_SELF` (cấp cho vai trò mặc định "Nhân viên" + Admin) và `SHIFT_REGISTRATION_MANAGE` (cần `SHIFT_VIEW`, cấp cho Admin).
- `tools/demo/clear_test_company.sql` đã thêm 3 bảng mới.

## 6. API

| Phương thức | Đường dẫn | Quyền |
|---|---|---|
| GET / POST | `/api/v1/shift-registration-rounds` (`open: true` = mở luôn) | SHIFT_VIEW + MANAGE |
| PUT / DELETE | `/api/v1/shift-registration-rounds/{id}` | SHIFT_VIEW + MANAGE |
| POST | `/{id}/open`, `/{id}/close` | SHIFT_VIEW + MANAGE |
| GET | `/{id}/board` (lưới người × ngày + ca có sẵn) | SHIFT_VIEW + MANAGE |
| POST | `/{id}/days/{yyyy-MM-dd}/approve` `{anyShiftId?}` → `{approved, skipped[]}` | SHIFT_VIEW + MANAGE |
| POST | `/api/v1/shift-registrations/{id}/approve` `{shiftId? \| startTime + endTime?}`, `/{id}/reject` | SHIFT_VIEW + MANAGE |
| GET | `/api/v1/shift-registrations/self/rounds` | SELF |
| GET / PUT | `/api/v1/shift-registrations/self/rounds/{id}` (PUT `{slots: [{workDate, kind, shiftId?, startTime?, endTime?}]}`) | SELF |

Cài đặt: `CompanySettingDTO.shiftRegistration.enabled` (PUT `/api/v1/company-settings`, không gửi = giữ).
Mã lỗi `error.shift_registration.*` (dịch ở `error_utils.dart`). Nhật ký `SHIFT_REG_ROUND_CREATE|UPDATE|DELETE|OPEN|CLOSE`, `SHIFT_REG_SUBMIT`,
`SHIFT_REG_APPROVE`, `SHIFT_REG_REJECT`. Báo đẩy khi mở đợt lần đầu.

## 7. Giao diện

- **Cài đặt công ty → Chung**: thẻ "Đăng ký lịch làm việc" + công tắc. `CompanyFeatureService` (FE) đọc cờ để hiện menu / tab.
- **Ca làm → tab "Đăng ký lịch"** (`shift/shift_registration_tab.dart`, cần cờ + SHIFT_VIEW + MANAGE): danh sách đợt (Mở / Đóng trên dòng,
  sửa / xoá ở menu ⋮), hộp tạo đợt (Tuần sau / 2 tuần tới / Tháng sau / Tự chọn, phòng ban nhiều chọn, hạn chót, giới hạn),
  lưới người × ngày (nút **Duyệt (n)** trên từng ngày, bấm ô chờ để duyệt / đổi / từ chối, bấm ngày → biểu đồ số người theo giờ).
- **Menu "Đăng ký lịch"** (nhóm Của tôi, `shift/my_shift_registration_screen.dart`): mỗi ngày bật làm, chọn Ca có sẵn / Giờ tuỳ chỉnh / Rảnh cả ngày,
  thêm khung 2; thanh dưới "N ngày · H giờ" + **Gửi đăng ký**. Ngày đã duyệt / đợt đóng chỉ xem.
- Kiểm khung phía FE: `core/utils/shift_registration_utils.dart` (test `test/shift_registration_utils_test.dart`).

## 8. Kiểm thử

`ShiftRegistrationTest` (7 ca): công ty tắt → 403; Nháp / Đóng → `not_open`, phòng khác → `not_in_scope`; kiểm khung (quá 2, chồng giờ, rảnh cả ngày
kèm khung khác, ngoài khung giờ, quá dài, ngày đã qua, số ngày tối thiểu); duyệt theo ngày (đúng giờ / đúng ca, rảnh cả ngày cần ca, trùng phân ca bị
bỏ qua, duyệt đổi giờ, ngày đã duyệt không sửa được, đợt có duyệt không xoá được); không tự duyệt + phạm vi phòng ban; đợt chồng ngày + tự đóng;
bật / tắt ở cài đặt.

## 9. Chưa làm

- Xuất Excel lưới đăng ký; nhắc 24 giờ trước hạn chót; cảnh báo ngày đã có đơn nghỉ / ngày lễ trên màn nhân viên.
- Trang trợ giúp + ảnh chụp (cần môi trường thử có dữ liệu mẫu), seed TH / Công ty test thêm một đợt mẫu.
