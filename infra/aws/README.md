# Hạ tầng AWS của BossKin (bước E)

`bosskin.yaml` là một stack CloudFormation dựng toàn bộ môi trường chạy thật:

| Thành phần | Chi tiết |
|---|---|
| Elastic Beanstalk | Java SE Corretto 17, ALB (hoặc 1 máy), health `/actuator/health`, log đẩy CloudWatch 30 ngày, cập nhật nền tảng tự động Chủ nhật 03:00 giờ VN |
| RDS MySQL 8.0 | Mã hoá, không mở Internet, chỉ nhận kết nối từ máy app, bắt buộc TLS, utf8mb4, sao lưu 7 ngày (01:00 giờ VN), chống xoá, xoá stack → giữ snapshot |
| S3 | Riêng tư, mã hoá, giữ phiên bản cũ 30 ngày, `excel-history/` tự xoá sau 1 năm. Chỉ `company-*/avatars/*` và `company-*/images/*` đọc công khai (app lưu URL ảnh trực tiếp). `documents/` (tài liệu nhân sự) chỉ tải qua link ký tạm. CORS `GET` theo `CorsAllowedOrigins` |
| IAM | Role máy EB: đọc/ghi đúng bucket của app + CloudWatch + SSM Session Manager (vào máy không cần SSH). Role dịch vụ EB |
| Secrets Manager | `<app>-<env>/jwt-secret`, `<app>-<env>/db`, `<app>-<env>/bootstrap-sysadmin` (chỉ khi có email system admin đầu tiên), tất cả sinh ngẫu nhiên |
| Cảnh báo | SNS `<app>-<env>-alarms`: CPU RDS > 80%, RDS còn < 2 GB, môi trường EB không ổn |

Biến môi trường app (runbook mục 2) được stack đặt sẵn: `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `JWT_SECRET`,
`AWS_S3_BUCKET`, `AWS_REGION`, `DOCUMENTS_STORAGE=s3`, `CORS_ALLOWED_ORIGINS`, `BOOTSTRAP_SYSADMIN_*`.
Các biến khác (`FIREBASE_SERVICE_ACCOUNT_JSON`, `SUPABASE_*`…) thêm tay ở EB → Configuration → Environment properties.

> Giá trị bí mật được CloudFormation lấy từ Secrets Manager lúc tạo/cập nhật stack và ghi vào Environment properties,
> nên ai có quyền xem cấu hình EB sẽ thấy. Chỉ cấp quyền console EB cho người vận hành.

## Kiểm tra file

```bash
pip install cfn-lint   # hoặc dùng venv
cfn-lint infra/aws/bosskin.yaml
```

CI chạy lệnh này ở `.github/workflows/infra-lint.yml` mỗi khi `infra/**` đổi.

## Dựng lần đầu (Bước 3)

1. **Chuẩn bị**: tài khoản AWS, region (gợi ý `ap-southeast-1` Singapore), chứng chỉ ACM cho tên miền API
   (vd. `api.bosskin.vn`, xác thực DNS) cùng region.
2. **Chọn nền tảng EB** mới nhất:
   `aws elasticbeanstalk list-available-solution-stacks --query "SolutionStacks[?contains(@, 'Corretto 17')]"`.
3. **Tạo stack** (console CloudFormation → Create stack → upload `bosskin.yaml`, hoặc CLI):

   ```bash
   aws cloudformation deploy --stack-name bosskin-prod \
     --template-file infra/aws/bosskin.yaml \
     --capabilities CAPABILITY_IAM \
     --parameter-overrides \
       VpcId=vpc-xxx AppSubnetIds=subnet-a,subnet-b DbSubnetIds=subnet-a,subnet-b \
       SolutionStackName="64bit Amazon Linux 2023 v4.x.y running Corretto 17" \
       CertificateArn=arn:aws:acm:...:certificate/... \
       CorsAllowedOrigins=https://app.bosskin.vn,https://bosskin.vn \
       BootstrapSysadminEmail=admin@bosskin.vn
   ```

   VPC mặc định dùng được (subnet mặc định đều public; RDS vẫn không mở Internet vì `PubliclyAccessible=false`
   và security group chỉ nhận từ máy app). Lần đầu mất khoảng 15–20 phút (RDS lâu nhất).
4. **Đăng ký email cảnh báo**: SNS → topic `bosskin-prod-alarms` → Create subscription (Email).
5. **Deploy code**: tạo IAM user deploy (policy `AdministratorAccess-AWSElasticBeanstalk`), đặt GitHub secrets
   `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `EB_APPLICATION_NAME`, `EB_ENVIRONMENT_NAME`
   (hai giá trị cuối lấy ở Outputs của stack), rồi chạy workflow **Deploy to Elastic Beanstalk**.
6. **Tên miền**: CNAME `api.<tên-miền>` → `AppUrl` trong Outputs. Bản web/app build với API trỏ về đó.
7. **System admin đầu tiên**: mật khẩu ở Secrets Manager `bosskin-prod/bootstrap-sysadmin`. Đăng nhập, cài 2FA,
   đổi mật khẩu, rồi update stack với `BootstrapSysadminEmail=` (trống) để gỡ biến bootstrap.

## Thay đổi sau này

- Đổi thông số (loại máy, số máy, dung lượng DB…): update stack với tham số mới. Đổi `DbInstanceClass` gây
  khởi động lại DB vài phút; làm ngoài giờ.
- Đổi mật khẩu DB / JWT: sửa giá trị trong Secrets Manager (DB thì đổi cả trên RDS), rồi update stack (không đổi gì)
  để EB nhận giá trị mới. Đổi JWT làm mọi người phải đăng nhập lại.
- Sao lưu / khôi phục / sự cố: `docs/runbook.md`.
- Xoá stack: RDS bị chặn xoá (`DeletionProtection`); bucket giữ lại (`Retain`). Không xoá khi chưa có bản sao dữ liệu.
