# Tính năng theo công ty — bật / tắt từng tính năng (V26)

Trạng thái: **giai đoạn 1 xong (15/10/2026)**, giai đoạn 2 đang chờ. Phần kỹ thuật chạy được ở `core/CompanyFeatures`, `core/FeatureRoutes`,
`security/FeatureRouteInterceptor`; mô tả chặn quyền ở [phân quyền](../he-thong/phan-quyen.md).

## Quyết định của chủ dự án (15/10/2026)
1. App **chỉ cần công tắc** bật / tắt từng tính năng; tiền do chủ dự án tự tính ngoài app → **không làm** bảng giá, sao kê, gói bán sẵn (`plans`).
2. Tắt / bật có **hiệu lực ngay** (không lập lịch đầu tháng). Nhật ký `COMPANY_FEATURES` ghi ai đổi gì lúc nào, đủ để đối chiếu khi tính tiền.
3. Chia **càng chi tiết càng tốt**: giữ các tính năng dấu `?` ở dạng tách riêng.
4. Mọi công ty đang dùng **giữ nguyên** những gì đang bật (migration V26 chuyển đúng từ 7 gói V24).

## Hiện trạng trước V26
7 gói thô (ATTENDANCE, SHIFT, LEAVE, PAYROLL, CONTRACT, DOCUMENT, REPORT), chặn bằng tiền tố mã quyền. Không đủ mịn: nhiều tính năng con dùng chung một mã quyền
(vd. `SHIFT_MANAGE` phủ phân ca + xoay ca; `ATTENDANCE_SELF` là quyền "tôi là nhân viên" dùng cả cho phiếu lương và đổi ca), và cột 200 ký tự không chứa nổi ~40 mã.

## Danh mục (33 tính năng bật / tắt được + 7 mục nền luôn có). `?` = chưa chắc nên tách, giữ tách theo ý chủ dự án "càng chi tiết càng tốt"
Quy ước "Tắt thì sao": **API** = trả 403 `error.company.module_disabled`; **UI** = ẩn; **Dữ liệu** = giữ nguyên, chỉ đọc / bỏ qua; **Job** = bỏ qua công ty đó.

### 0. Nền — luôn có, không tính tiền riêng
CORE_EMPLOYEE (hồ sơ NV, tài khoản, hồ sơ cá nhân + sửa hồ sơ + duyệt sửa), CORE_ORG (phòng ban, chức vụ), CORE_ROLE (vai trò, phân quyền),
CORE_SETTING, CORE_DASHBOARD (thẻ cơ bản), CORE_AUDIT, CORE_SECURITY (mật khẩu, 2FA, che dữ liệu nhạy cảm — KHÔNG bán lẻ).

### 1. Chấm công
| Mã | Là gì | Cần | Tắt thì sao |
|---|---|---|---|
| ATT_SHEET | Bảng công, sửa tay, duyệt (từng dòng + hàng loạt), khoá kỳ, tăng ca (cài `otEnabled`), dung sai / làm tròn | — | API chấm công 403; UI ẩn Chấm công; dữ liệu công cũ giữ, không xem được; lương không còn công mới |
| ATT_SELF | Tự check-in / out (web + app) | ATT_SHEET | API `/self/*` 403; ẩn Check-in; nhắc chấm công (job) bỏ qua |
| ATT_GEOFENCE | Kiểm tra vị trí GPS, vị trí theo phòng / NV | ATT_SELF | Không kiểm vị trí (ai cũng chấm được) — cài đặt bị bỏ qua, ẩn mục cài đặt |
| ATT_DEVICE | Gắn thiết bị chống chấm hộ | ATT_SELF | Không kiểm thiết bị; ẩn mục gắn / gỡ |
| ATT_NOSHIFT | Chấm khi không được xếp ca (V25) | ATT_SELF | Ngày không ca không chấm được; công không ca đã có giữ nguyên |
| ATT_REQUEST | Yêu cầu chấm công / sửa giờ / tăng ca + duyệt | ATT_SHEET | API yêu cầu 403; đơn chờ duyệt giữ, không xử lý được `?` |
Ràng buộc kiểm lúc LƯU (không phải cạnh phụ thuộc, hết vòng): bật ATT_SELF mà không bật SHIFT_BASIC thì bắt buộc bật ATT_NOSHIFT.
(Luật cũ "ATTENDANCE cần SHIFT" không còn đúng khi có ATT_NOSHIFT.)

### 2. Ca làm
| Mã | Là gì | Cần | Tắt thì sao |
|---|---|---|---|
| SHIFT_BASIC | Ca cố định, phân ca (lưới, Excel) | — | API ca 403; ẩn Ca làm; phân ca cũ giữ; chấm công chỉ còn ATT_NOSHIFT |
| SHIFT_ADVANCED `?` | Ca linh hoạt, ca gãy, ca qua đêm, nhiều ca / ngày | SHIFT_BASIC | Không tạo ca loại đó nữa; ca đã phân vẫn tính công bình thường |
| SHIFT_ROTATION | Mẫu xoay ca, sinh phân ca | SHIFT_BASIC | Ẩn tab Xoay ca, API 403; phân ca đã sinh giữ |
| SHIFT_SWAP | Đổi / nhường ca + duyệt | SHIFT_BASIC | Ẩn màn Đổi ca, API 403; đơn chờ giữ, không xử lý |
| SHIFT_REGISTRATION | Đăng ký lịch làm việc theo đợt | SHIFT_BASIC | Đã có công tắc công ty (V23); thêm chặn theo gói; đợt đang mở: job tự đóng bỏ qua |
| SHIFT_REMINDER | Nhắc ca / nhắc chấm công qua thông báo đẩy | SHIFT_BASIC | 2 job FCM bỏ qua công ty; cài đặt nhắc của NV ẩn |

### 3. Lịch & ngày lễ
| CAL_WORKCAL | Lịch làm việc theo phòng ban (F / H / O) | — | Dùng lịch mặc định `FFFFFOO`; ẩn tab; công chuẩn lương tính theo lịch mặc định |
| CAL_HOLIDAY | Ngày lễ, nghỉ bù, làm bù, mẫu theo năm | — | Không có ngày lễ: đơn nghỉ / lương coi mọi ngày là thường; dữ liệu lễ cũ giữ |

### 4. Nghỉ phép
| LEAVE_BASIC | Loại nghỉ, đơn nghỉ (cả theo giờ), duyệt | — | API 403; ẩn Nghỉ phép; đơn / phép cũ giữ; trừ phép trong lương bỏ qua |
| LEAVE_BALANCE | Quỹ phép, cấp thủ công, sổ trừ / hoàn | LEAVE_BASIC | Không kiểm số dư khi tạo đơn; quỹ giữ nguyên |
| LEAVE_ACCRUAL | Quy tắc cộng phép tự động | LEAVE_BALANCE | Job `LeaveAccrualScheduler` bỏ qua; quy tắc giữ |

### 5. Tính lương
| PAY_BASIC | Bậc lương, bảng lương, duyệt / trả, phiếu lương của tôi, xuất Excel lương | — | API lương 403; ẩn Lương + Phiếu lương; bậc lương trên form NV ẩn; phiếu cũ giữ |
| PAY_FORMULA | Biến & công thức tuỳ biến | PAY_BASIC | Dùng công thức mặc định; ẩn tab công thức; công thức cũ giữ, không chạy |
| PAY_TAX_INS | Thuế TNCN, BHXH / BHYT / BHTN, chính sách hiệu lực | PAY_BASIC | Lương không trừ thuế / BH (cần xác nhận cách tính) `?` |
| PAY_DEPENDENT | Người phụ thuộc, MST, sổ BHXH | PAY_TAX_INS | Ẩn mục Thuế & BH ở form NV; số người phụ thuộc = 0 |
| PAY_EMPLOYER_COST | BH công ty đóng + tổng chi phí | PAY_TAX_INS | Ẩn cột; phiếu không có phần công ty đóng |

### 6. Nhân sự mở rộng
| HR_CONTRACT | Hợp đồng, phụ lục, phụ cấp theo HĐ (vào lương) | — | API 403; ẩn Hợp đồng; lương dùng `contract_salary` cũ; phụ cấp HĐ không vào lương |
| HR_CONTRACT_ALERT | Cảnh báo HĐ sắp hết hạn + đẩy | HR_CONTRACT | Job 07:30 bỏ qua phần báo; thẻ Tổng quan ẩn |
| HR_DOCUMENT | Tài liệu nhân sự, loại tài liệu, duyệt | — | API 403; ẩn Tài liệu; file giữ |
| HR_DOCUMENT_ALERT | Cảnh báo tài liệu hết hạn / thiếu | HR_DOCUMENT | Job 07:35 bỏ qua; thẻ Tổng quan ẩn |
| HR_ORGCHART | Sơ đồ tổ chức + quản lý trực tiếp | — | Ẩn sơ đồ + ô quản lý; liên kết quản lý giữ |
| HR_JOBHISTORY | Quá trình công tác, mốc tương lai | — | Ẩn hộp; job 00:05 `applyDue` bỏ qua (mốc tương lai không tự áp) |
| HR_MANAGER_APPROVAL | Duyệt 2 cấp (quản lý → HR), màn duyệt của quản lý | HR_ORGCHART | Chế độ MANAGER_THEN_HR bị bỏ qua (về PERMISSION); ẩn màn; đơn chờ quản lý: HR duyệt thẳng |

### 7. Báo cáo & dữ liệu
| RPT_OVERVIEW | Báo cáo nhân sự / chấm công / tổng quan năm | — | API báo cáo 403; ẩn Báo cáo |
| RPT_PAYROLL | Báo cáo lương | PAY_BASIC | Bỏ sheet / mục lương |
| RPT_INSURANCE | DS đóng BH, báo cáo người phụ thuộc (hiện chỉ cần EMPLOYEE_VIEW — đổi sang cần PAY_DEPENDENT là thay đổi hành vi) | PAY_DEPENDENT | 403 hai báo cáo |
| DATA_EXCEL | Nhập / xuất Excel tổng hợp + file mẫu (12 mô tả) | — | Ẩn Import / Export; sheet của gói tắt tự bị lọc |

Đã LOẠI so với v1: HR_SENSITIVE (kiểm soát bảo mật, tắt = lộ / mất dữ liệu), DATA_ONBOARD (script offline), PAY_EXPORT (không có PDF; Excel lương thuộc PAY_BASIC),
ATT_OT / ATT_POLICY (là cài đặt trong ATT_SHEET), LEAVE_HOURLY (gộp LEAVE_BASIC), HR_SELF_EDIT (gộp CORE_EMPLOYEE).

## Móc nối phải gắn tính năng (bảng đối chiếu)
- 7 job `@Scheduled`: CheckInOutReminderScheduler + ShiftReminderScheduler → SHIFT_REMINDER; LeaveAccrualScheduler → LEAVE_ACCRUAL;
  JobHistoryService.applyDue → HR_JOBHISTORY; ContractService.dailyJob → HR_CONTRACT (đồng bộ lương) + HR_CONTRACT_ALERT (báo);
  DocumentService.dailyJob → HR_DOCUMENT_ALERT; ShiftRegistrationService.autoClose → SHIFT_REGISTRATION.
- 12 descriptor Excel: Department 10 / Position 20 → CORE; SalaryGrade 30 / SalaryFormula 70 / Payroll 120 / FormulaVariable 60 → PAY_BASIC (công thức: PAY_FORMULA);
  Shift 40 / ShiftAssignment 100 → SHIFT_BASIC; LeaveType 50 / LeaveGrant 90 → LEAVE_BASIC / LEAVE_BALANCE; Employee 80 → CORE; Attendance 110 → ATT_SHEET. Contract import riêng → HR_CONTRACT.
- Thẻ Tổng quan + `/dashboard/risks`: contractExpiring → HR_CONTRACT_ALERT; documentExpiring → HR_DOCUMENT_ALERT; thẻ lương → PAY_BASIC; thẻ chấm công → ATT_SHEET; thẻ nghỉ → LEAVE_BASIC.
  (CLAUDE.md đang ghi "chưa làm: ẩn thẻ Tổng quan + tắt job nền theo gói" — chia nhỏ khiến việc này BẮT BUỘC.)


## Kỹ thuật đã làm (giai đoạn 1)
- Danh mục trong code (`CompanyFeatures.CATALOG`, enum + cạnh "cần"), app có bản sao `company_feature_utils.dart`; CI `tools/ci/check_features.py` kiểm hai bên khớp (mã, nhóm, "cần", nhãn vi + en).
- Lưu: `companies.disabled_features varchar(1000)` (danh sách mã TẮT, NULL = bật hết) — V26 chuyển từ `disabled_modules` rồi bỏ cột cũ. Không cần bảng lịch sử vì tính tiền ngoài app.
- Chặn API tập trung: `FeatureRoutes` (đường dẫn → tính năng) + `FeatureRouteInterceptor` → 403 `error.company.feature_disabled`; không rải kiểm tra vào từng endpoint.
- Quyền: `User.getPermissions()` bỏ mã quyền gắn riêng với tính năng tắt; quyền chung thuộc tính năng gốc của gói.
- Tương thích: đăng nhập / làm mới token trả cả `features` và `modules` (app đã cài chỉ đọc `modules`); `PUT /admin/companies/{id}` nhận `features` hoặc `modules`.
- App: `AuthUser.hasFeature`, `routeFeature` (nav_access), hộp "Sửa công ty" chia nhóm có tự bật / tắt theo "cần", Cài đặt công ty ẩn mục của tính năng tắt,
  app tự lấy lại tính năng khi mở và khi API trả 403 `feature_disabled`. Menu đã tự ẩn tiêu đề nhóm khi mọi mục con ẩn.
- Thay đổi hành vi so với V24 (đã chấp nhận): báo cáo bảo hiểm / người phụ thuộc (`RPT_INSURANCE`) nay cần `PAY_DEPENDENT`; công ty đã tắt gói Tính lương nên tự tắt hai báo cáo đó.

## Tắt tính năng thì hệ thống làm gì (đã làm)
Nguyên tắc: **cài đặt mà màn Cài đặt ẩn vì tính năng tắt thì backend coi như TẮT** (không kẹt giá trị cũ không sửa được, không hưởng tính năng chưa đăng ký).
Dữ liệu cũ luôn giữ nguyên, không xoá.
| Tính năng | Khi tắt |
|---|---|
| ATT_SHEET, ATT_SELF, ATT_REQUEST | API chặn (403), ẩn màn; `ATT_SELF` tắt: nhắc chấm công vẫn theo `SHIFT_REMINDER` |
| ATT_GEOFENCE / ATT_DEVICE / ATT_NOSHIFT | không kiểm vị trí / thiết bị; ngày không ca không chấm được; ẩn công tắc ở Cài đặt (`Company.locationCheckActive()` …) |
| SHIFT_BASIC / ROTATION / SWAP / REGISTRATION | API chặn, ẩn màn / tab; đăng ký lịch tắt thì job tự đóng đợt vẫn chạy trên đợt đã có |
| SHIFT_ADVANCED | không tạo / sửa thành ca linh hoạt hoặc ca qua đêm; ca đã tạo vẫn dùng. (Ca gãy / nhiều ca một ngày vẫn là ca thường) |
| SHIFT_REMINDER | 2 job nhắc ca / nhắc chấm công bỏ qua công ty |
| CAL_WORKCAL / CAL_HOLIDAY | chặn API quản lý lịch / ngày lễ (`/work-calendars/view` luôn đọc được). **Chưa làm**: lương, nghỉ phép vẫn dùng lịch + ngày lễ đã có |
| LEAVE_BASIC / BALANCE / ACCRUAL | API chặn, ẩn màn; job cộng phép bỏ qua công ty |
| PAY_BASIC / FORMULA | API chặn, ẩn màn; thẻ "NV chưa có bậc lương" ở Tổng quan ẩn |
| PAY_TAX_INS | phiếu lương **không trừ** thuế TNCN / BHXH / BHYT / BHTN (cả khi công thức riêng có đặt) |
| PAY_DEPENDENT | API người phụ thuộc chặn; số người phụ thuộc trong lương = 0; ẩn nút ở danh sách nhân viên |
| PAY_EMPLOYER_COST | phần BH công ty đóng trên phiếu = 0; ẩn 3 ô tỷ lệ ở Cài đặt |
| HR_CONTRACT | API chặn, ẩn màn |
| HR_CONTRACT_ALERT / HR_DOCUMENT_ALERT | chặn danh sách sắp hết hạn / thiếu; job 07:30 / 07:35 không gửi thông báo; thẻ Tổng quan ẩn; ẩn ô số ngày báo trước ở Cài đặt |
| HR_ORGCHART / HR_JOBHISTORY | API chặn, ẩn màn / nút. Job `applyDue` vẫn chạy (mốc công tác tương lai là dữ liệu nhân viên cốt lõi) |
| HR_MANAGER_APPROVAL | chế độ duyệt hiệu lực = theo quyền (đơn chờ quản lý duyệt được ngay, không kẹt); ẩn màn + ô chọn chế độ |
| RPT_* / DATA_EXCEL | API báo cáo / Excel chặn, ẩn màn |

## Còn lại (giai đoạn 2)
- Lương / nghỉ phép vẫn dùng lịch làm việc và ngày lễ khi `CAL_*` tắt (hiện chỉ chặn API quản lý).
- Thẻ Tổng quan khác (chấm công, lương, nghỉ) chưa lọc theo tính năng; sheet Excel / báo cáo năm gộp nhiều gói chưa lọc theo từng tính năng.
- Mô tả Excel theo tính năng (12 mô tả): Department / Position / Employee → nền; SalaryGrade / SalaryFormula / FormulaVariable / Payroll → PAY_*;
  Shift / ShiftAssignment → SHIFT_BASIC; LeaveType / LeaveGrant → LEAVE_*; Attendance → ATT_SHEET — hiện lọc theo quyền đã gỡ.
- Ẩn nút / tab bên trong các màn vẫn hiển thị theo `hasFeature` — **đã làm**: thẻ nhân viên (quá trình công tác, người phụ thuộc), Hồ sơ cá nhân (người phụ thuộc, tài liệu),
  Bảng lương (tab Biến / Công thức), Ca làm (tab Xoay ca / Đăng ký lịch), Nghỉ phép (quỹ phép, quy tắc cộng phép không gọi khi tắt), Cài đặt công ty (từng mục),
  form nhân viên (vị trí / thiết bị chấm công), menu. Tab "Lịch làm việc" ở Cài đặt cần cả `CAL_WORKCAL` lẫn `CAL_HOLIDAY` (tab gọi cả hai API). Bản đồ nền (`/api/v1/map-tiles`) dùng chung nên không gắn tính năng.
- Ô "gói hiệu lực khi triển khai": app điện thoại đã cài chỉ đọc `modules` nên vẫn thấy menu con của tính năng nhỏ đã tắt và thấy mã lỗi `error.company.feature_disabled` chưa dịch
  cho tới khi cập nhật app.
