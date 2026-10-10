# Chuyển dữ liệu thật sang BossKin và chạy song song (bước E)

## 1. Nhập dữ liệu ban đầu

Mẫu ở `tools/onboarding/mau/`. Có 4 file, nhập lần lượt: file sau dùng mã của file trước, nên màn xem trước
chỉ đúng khi file trước đã nhập xong. `tools/onboarding/mau/vi-du/` là bản đã điền dữ liệu hư cấu để tham khảo.

| File | Sheet | Ghi chú |
|---|---|---|
| `1-phong-ban.xlsx` | Phòng ban | Mã phòng ban, phòng cha, toạ độ + bán kính chấm công (để trống thì chấm ở đâu cũng được) |
| `2-danh-muc.xlsx` | Chức vụ, Bậc lương, Danh sách ca, Loại nghỉ phép | Bậc lương DAILY / HOURLY + mức cơ bản; ca cố định (ca linh hoạt tạo ở màn Ca làm) |
| `3-nhan-vien.xlsx` | Nhân viên | Đủ cột hồ sơ: CCCD, tài khoản ngân hàng, MST, số sổ BHXH, lương hợp đồng… |
| `4-so-du-phep-phan-ca.xlsx` | Số dư phép, Phân công ca | Phép còn lại lúc chuyển hệ thống; lịch ca những ngày đầu |

Mỗi file có sheet **Hướng dẫn** (định dạng ngày, giá trị hợp lệ). Cách nhập: màn **Excel** → chọn file → xem trước
(Tạo mới / Cập nhật / Không đổi / lỗi từng dòng) → Xác nhận → tải file kết quả để xem dòng lỗi, sửa rồi nhập lại.
Lệnh `MERGE` (mặc định) thêm hoặc cập nhật theo mã nên nhập lại cùng file không tạo trùng, kể cả số dư phép
(một quỹ phép = mã NV + loại phép + ngày cấp).

**Tài khoản nhân viên:** mỗi dòng có email được tạo tài khoản đăng nhập bằng email đó với **mật khẩu ngẫu nhiên**
(mỗi người một mật khẩu, không ai biết trước). Nhập xong vào **Phân quyền → Người dùng → Xuất mật khẩu tạm**: hệ thống
cấp mật khẩu tạm mới cho mọi tài khoản chưa đổi mật khẩu lần đầu và tải về file Excel (mã NV, họ tên, phòng ban, email,
mật khẩu tạm) để phát cho từng người; mỗi người phải đổi mật khẩu ở lần đăng nhập đầu. Xuất lần nữa thì mật khẩu tạm
cũ hết hiệu lực. Ai quên mật khẩu sau này: biểu tượng chìa khoá cạnh tên ở tab Người dùng (đặt lại từng người).
File mật khẩu tạm là dữ liệu nhạy cảm: phát xong thì xoá, không gửi qua nhóm chat chung.

**SĐT, CCCD, số tài khoản:** cột chữ trong file xuất đã định dạng Text nên gõ số 0 đầu vẫn giữ. Nếu dán từ file khác
mà Excel đã đổi thành số, SĐT 9 chữ số và CCCD 10–11 chữ số được tự bù số 0 khi nhập; số tài khoản ngân hàng không đoán
được, hãy để dạng Text.

**Số dư phép:** ghi số ngày còn được nghỉ (không phải số được cấp cả năm), ngày cấp = ngày bắt đầu dùng BossKin,
hiệu lực đến = hạn dùng. Có thể sửa sau bằng cách sửa số trong file rồi nhập lại (không được nhỏ hơn số đã dùng).

**Không nhập:** chấm công và bảng lương cũ. Giữ ở hệ thống cũ, đối chiếu ở mục 2.

Tạo lại mẫu khi đổi cột: tạo một công ty trống, Excel → Xuất 8 loại trên (tiếng Việt, Nhân viên chọn mọi cột nhập được),
rồi `python3 tools/onboarding/make_template.py <file-xuất.xlsx> tools/onboarding/mau`.

## 2. Chạy song song (pilot) và đối chiếu

Trong 1–2 kỳ lương đầu, chấm công và tính lương ở cả hệ thống cũ và BossKin, cuối kỳ so từng người:

```bash
# Công: BossKin → Excel → Xuất → Chấm công (cả kỳ). File cũ: mỗi NV một dòng (tổng kỳ)
python3 tools/onboarding/doi_chieu.py cong --bosskin cham-cong.xlsx --cu cong-cu.xlsx --ra doi-chieu-cong.xlsx \
    --cot "Mã NV=Mã nhân viên" --cot "Ngày có công=Công thực tế"

# Lương: BossKin → Excel → Xuất → Bảng lương (kỳ cần so)
python3 tools/onboarding/doi_chieu.py luong --bosskin bang-luong.xlsx --cu luong-cu.xlsx --ra doi-chieu-luong.xlsx \
    --cot "Mã NV=Mã nhân viên" --cot "Net (thực lãnh)=Thực lĩnh"
```

- Cột so (BossKin): công = Ngày có công, Giờ thực tế, OT ngày, OT đêm; lương = Ngày công, Giờ ngày / đêm,
  Giờ OT ngày / đêm, Lương cơ bản, Tổng trợ cấp, Tổng thu nhập, Gross, Tổng khấu trừ, Net. Cột nào file cũ không có thì bỏ qua.
- File cũ khác tên cột → `--cot "<cột BossKin>=<cột file cũ>"`. Số kiểu `1.234.567` hay `7,5` đều đọc được; .csv phải UTF-8.
- Sai số cho phép: `--sai-so` (công / giờ, mặc định 0,01), `--sai-so-tien` (mặc định 1.000 đ, do làm tròn).
- Kết quả: sheet Tổng hợp, Chênh lệch (từng NV × cột, lệch = BossKin − cũ), Chỉ có ở BossKin, Chỉ có ở file cũ.
  Lệnh trả mã 0 khi khớp hết, 1 khi còn chênh lệch.

Xử lý chênh lệch: kiểm tra dòng công của NV đó ở BossKin (thiếu giờ vào/ra, đơn sửa giờ chưa duyệt, ngày lễ, ca đêm),
cấu hình công thức lương / bậc lương, rồi tính lại bảng lương nháp. Lệch do hệ thống cũ sai thì ghi chú vào biên bản pilot
(`docs/pilot-2026-10.md`).
