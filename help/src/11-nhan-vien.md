---
title: Nhân viên và sơ đồ tổ chức
group: Nhân sự
who: Nhân sự, quản trị
summary: Danh sách nhân viên, thêm / sửa hồ sơ, quản lý trực tiếp, quá trình công tác, người phụ thuộc, tài liệu, sơ đồ tổ chức.
---

## Danh sách nhân viên

Mở **Nhân viên**. Tìm theo tên, email, mã NV; lọc theo phòng ban và trạng thái (đang làm, nghỉ việc…). Mỗi dòng có các nút:

| Nút | Chức năng |
|---|---|
| 📈 | Quá trình công tác (chuyển phòng, thăng chức, đổi lương, đổi quản lý) |
| 👪 | Người phụ thuộc (giảm trừ gia cảnh) |
| 📁 | Tài liệu nhân sự của người đó |
| 💵 | Lịch sử lương |
| ✏️ | Sửa hồ sơ |
| 🚫 (đỏ) | **Nghỉ việc**: chọn ngày làm việc cuối (không sau hôm nay). Trạng thái thành *Nghỉ việc*, tài khoản bị khoá và đăng xuất mọi máy, cấp dưới không còn quản lý trực tiếp này, ca đã xếp sau ngày nghỉ (chưa có công) được gỡ. Hồ sơ **không bị xoá**: lọc trạng thái *Nghỉ việc* để xem lại |
| 👤+ (người đã nghỉ) | **Đi làm lại**: trạng thái về *Đang làm*, bỏ ngày nghỉ, mở lại tài khoản (quản lý trực tiếp chọn lại trong hồ sơ nếu cần) |

![Danh sách nhân viên](img:employees)

> **Lưu ý:** Số CCCD, số tài khoản, MST, sổ BHXH hiện dạng `****1234` nếu bạn không có quyền *Xem dữ liệu nhạy cảm*.

## Thêm nhân viên

1. Bấm **Thêm nhân viên**.
2. Nhập **Họ và tên**, **Email công việc** (dùng để đăng nhập), mật khẩu tạm, giới tính, ngày vào làm.
3. Chọn **Phòng ban**, **Chức vụ** và **Quản lý trực tiếp** (người duyệt bước 1 nếu bật duyệt 2 bước).
4. Chọn **Bậc lương**; nhập lương hợp đồng nếu chưa có hợp đồng lao động.
5. Điền thông tin bổ sung (địa chỉ, CCCD, ngân hàng, MST, BHXH) nếu có → bấm **Tạo**.

![Form thêm nhân viên](img:employee-new)

![Phần bậc lương, thông tin bổ sung, thuế & bảo hiểm](img:employee-new-2)

Mã nhân viên (EMP00001…) được cấp tự động, không bao giờ trùng — kể cả sau khi xoá nhân viên. Người mới đăng nhập bằng email + mật
khẩu tạm và phải đổi mật khẩu ngay. Thêm nhiều người một lúc: dùng [Import / Export](import-export.html), rồi
**Phân quyền → Người dùng → Xuất mật khẩu tạm** để lấy file mật khẩu phát cho từng người.

**Đồng bộ tài khoản**: tạo tài khoản đăng nhập cho các nhân viên chưa có (nhập một mật khẩu ban đầu chung, bắt đổi lần đầu).

## Sửa hồ sơ

Bấm ✏️ → sửa → **Lưu**. Đổi phòng ban / chức vụ / bậc lương / quản lý ở form sửa sẽ tự ghi một mốc *Quá trình công tác* với ngày hôm nay.
Nhân viên đã có hợp đồng lao động thì lương do hợp đồng quản lý (không sửa ở đây).

![Sửa hồ sơ nhân viên](img:employee-edit)

## Quá trình công tác

Bấm 📈. Mỗi mốc là ảnh chụp phòng ban, chức vụ, bậc lương, quản lý **từ một ngày hiệu lực**. Dùng **Thêm mốc** để ghi chuyển phòng /
thăng chức có hiệu lực **trong tương lai**: tới đúng ngày hệ thống tự áp dụng. Chỉ xoá được mốc chưa tới ngày.

![Quá trình công tác](img:job-history)

Bảng lương lấy phòng ban và bậc lương theo mốc hiệu lực ở cuối kỳ, nên nhân viên chuyển phòng giữa tháng vẫn tính đúng.

## Người phụ thuộc

Bấm 👪 → **Thêm người phụ thuộc**: họ tên, quan hệ, ngày sinh, MST / CCCD, tháng bắt đầu – kết thúc giảm trừ và trạng thái đăng ký với
cơ quan thuế. Trạng thái *Chưa đăng ký* thì không được tính giảm trừ; *Đã nộp, chờ MST* và *Đã đăng ký* được tính.

![Người phụ thuộc của một nhân viên](img:dependents)

## Tài liệu của nhân viên

Bấm 📁 để xem / tải lên giấy tờ của người đó; dòng màu cam báo loại bắt buộc còn thiếu. Chi tiết ở [Tài liệu nhân sự](tai-lieu.html).

![Tài liệu của một nhân viên](img:employee-documents)

## Sơ đồ tổ chức

Mở **Sơ đồ tổ chức**:

- **Theo người** — cây quản lý trực tiếp (ai báo cáo cho ai). Bấm mũi tên để mở / thu nhánh.
- **Theo phòng ban** — từng phòng và danh sách người trong phòng, kèm quản lý của mỗi người.

![Sơ đồ theo người](img:org-chart)

![Sơ đồ theo phòng ban](img:org-chart-dept)
