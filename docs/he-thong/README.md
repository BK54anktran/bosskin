# Tài liệu hệ thống BossKin

Tài liệu kỹ thuật nội bộ cho người phát triển và vận hành. Hướng dẫn cho người dùng cuối nằm ở trang trợ giúp `help/`
(dựng bằng `python3 help/tools/build_help.py`, xem [help/README.md](../../help/README.md)).

| Trang | Nội dung | Cách cập nhật |
|---|---|---|
| [Kiến trúc](kien-truc.md) | Thành phần, đường đi request, đa công ty, cấu trúc code BE/FE, Excel, lịch chạy nền, thông báo, lưu file | Viết tay |
| [Phân quyền](phan-quyen.md) | Vai trò, quyền, phạm vi phòng ban, quyền trực tiếp, quản lý trực tiếp, dữ liệu nhạy cảm | Viết tay |
| [Danh mục quyền](quyen.md) | Toàn bộ mã quyền, quyền phụ thuộc, nơi dùng ở BE / FE, kiểm tra đồng bộ | **Tự sinh** |
| [Nghiệp vụ](nghiep-vu.md) | Các module và luồng chính từ ca → công → phép → lương | Viết tay |
| [Danh sách API](api.md) | 300+ endpoint theo controller, quyền kiểm ở mỗi endpoint | **Tự sinh** |
| [Cơ sở dữ liệu](csdl.md) | 50 bảng, cột, khoá ngoại, ràng buộc duy nhất | **Tự sinh** |
| [Bảo mật](bao-mat.md) | Xác thực, 2FA, chống dò mật khẩu, gắn thiết bị, che dữ liệu, file riêng tư, nhật ký | Viết tay |
| [Triển khai & vận hành](trien-khai.md) | Môi trường dev, cấu hình, build, CI/CD, AWS, việc chạy nền, sao lưu | Viết tay |

Tài liệu liên quan: [runbook vận hành](../runbook.md) · [hạ tầng AWS](../../infra/aws/README.md) ·
[chuyển dữ liệu khách hàng](../chuyen-du-lieu.md) · [kịch bản UAT](../uat-kich-ban.md) · [thử trên điện thoại](../thu-dien-thoai.md) ·
[review 10/2026 (sơ đồ ER, luồng nghiệp vụ có hình)](../review-2026-10/index.html) · quy tắc code ở `CLAUDE.md`.

## Giữ tài liệu khớp với code

Ba trang **tự sinh** lấy thẳng từ code và DB nên không sửa tay:

```bash
# DB đã chạy hết migration (vd. container MySQL dùng cho test / chụp ảnh trợ giúp)
MYSQL_CMD="docker exec -i <container> mysql -uroot -p<mật-khẩu> bosskin" python3 tools/docs/gen_he_thong.py
python3 tools/docs/gen_he_thong.py --check   # không cần DB: báo lệch api.md và csdl.md cũ hơn migration mới nhất
```

Quy tắc: đổi controller / quyền / migration ở commit nào thì sinh lại ở commit đó. Trang viết tay cập nhật cùng lúc với tính năng
(quy tắc "tài liệu – design – code – database luôn đi cùng nhau" trong `CLAUDE.md`).
