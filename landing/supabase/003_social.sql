-- Lịch đăng mạng xã hội (10/2026) — đã chạy trên project Supabase bosskin (apcppqwwnoyliwlhqtyx).
-- Kho media công khai: đọc bằng link /storage/v1/object/public/social/...
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('social','social', true, 52428800, array['image/jpeg','image/png','video/mp4'])
on conflict (id) do nothing;

-- Scheduled task chạy trên cloud tải media lên bằng khoá publishable: CHỈ thêm mới, CHỈ vào thư mục bí mật,
-- CHỈ jpg/mp4 (bucket giới hạn 50 MB). Không có quyền sửa/xoá/liệt kê. Tên thư mục bí mật nằm trong prompt của task.
create policy "social_auto_upload" on storage.objects for insert to anon
with check (bucket_id = 'social' and (storage.foldername(name))[1] = 'auto-<bí mật>'
            and lower(storage.extension(name)) in ('jpg','mp4'));

-- Nhật ký bài đã hẹn giờ (task ghi qua Supabase MCP; không mở quyền anon).
create table if not exists public.social_posts (
  id bigint generated always as identity primary key,
  post_date date not null,
  kind text not null,            -- starter | feature | law | tip | news | faq | recap
  topic text not null,
  media_url text not null,
  caption text,
  scheduled_at timestamptz,
  planner_url text,
  sources text,
  created_at timestamptz not null default now()
);
alter table public.social_posts enable row level security;
