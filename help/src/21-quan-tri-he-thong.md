---
title: Quản trị hệ thống (nhà cung cấp)
group: Quản trị
who: Quản trị viên hệ thống BossKin (không phải quản trị công ty)
summary: Cổng /admin: công ty khách hàng, yêu cầu dùng thử, quản trị viên, thông số thuế & bảo hiểm, ngày lễ mẫu.
---

Cổng quản trị hệ thống ở địa chỉ `/admin`, tài khoản riêng, **bắt buộc xác thực 2 lớp**.

![Đăng nhập quản trị hệ thống](img:admin-login)

## Công ty

Tạo công ty khách hàng (kèm tài khoản admin đầu tiên), khoá / mở công ty, bắt buộc 2FA cho quản trị của công ty (nút khiên), và **đăng nhập
thay** để hỗ trợ (nút mũi tên) — khi đang xem thay, app hiện dải cảnh báo và mọi thao tác ghi nhật ký.

![Danh sách công ty](img:admin-tab-2)

## Yêu cầu dùng thử

Yêu cầu gửi từ trang giới thiệu. Lọc theo trạng thái (Mới, Đã liên hệ, Đang dùng thử, Không phù hợp), ghi chú, xuất Excel.

![Yêu cầu dùng thử](img:admin-tab-3)

## Quản trị viên

Tạo quản trị viên hệ thống (mật khẩu sinh tự động, hiện một lần), khoá / mở, đặt lại mật khẩu, gỡ 2FA. Luôn còn ít nhất một quản trị
viên hoạt động; không thao tác lên chính mình.

![Quản trị viên](img:admin-tab-4)

## Thuế & BH

Thông số dùng chung cho mọi công ty, theo **ngày hiệu lực**: giảm trừ bản thân, giảm trừ người phụ thuộc, biểu thuế lũy tiến, mức tham chiếu
và hệ số trần BHXH/BHYT, lương tối thiểu 4 vùng và hệ số trần BHTN. Khi luật đổi, **Thêm chính sách** với ngày hiệu lực mới — các kỳ lương
cũ vẫn tính theo chính sách cũ.

![Thuế & BH](img:admin-tab-5)

## Ngày lễ mẫu

Danh sách ngày lễ mẫu theo năm cho mọi công ty chưa tự chỉnh. Cập nhật ngày nghỉ bù / hoán đổi theo thông báo chính thức hằng năm.

![Ngày lễ mẫu](img:admin-tab-6)
