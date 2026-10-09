-- Đã áp dụng lên Supabase project "bosskin" ngày 09/10/2026 (migration `trial_requests_handled`).
-- Người xử lý + thời điểm xử lý (backend BossKin ghi khi đổi trạng thái / ghi chú trong /admin).
alter table public.trial_requests add column handled_by text, add column handled_at timestamptz;
