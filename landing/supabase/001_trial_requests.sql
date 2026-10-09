-- Đã áp dụng lên Supabase project "bosskin" (apcppqwwnoyliwlhqtyx) ngày 09/10/2026 (migration `trial_requests`).
-- Lưu ở đây để biết cấu trúc / dựng lại khi cần. Cùng cột với trial_requests (V12) của BossKin để sau chuyển dữ liệu sang.
create table public.trial_requests (
  id bigint generated always as identity primary key,
  full_name text not null check (char_length(btrim(full_name)) between 2 and 100),
  company_name text not null check (char_length(btrim(company_name)) between 2 and 150),
  phone text not null,
  email text check (email is null or (char_length(email) <= 150 and email ~* '^[^\s@]+@[^\s@]+\.[^\s@]{2,}$')),
  company_size text check (company_size is null or char_length(company_size) <= 30),
  need text check (need is null or char_length(need) <= 1000),
  consent boolean not null check (consent),
  status text not null default 'NEW' check (status in ('NEW','CONTACTED','TRIAL','REJECTED')),
  admin_note text,
  source text check (source is null or char_length(source) <= 200),
  ip text,
  created_at timestamptz not null default now()
);
create index trial_requests_status_time on public.trial_requests (status, created_at desc);
create index trial_requests_phone_time on public.trial_requests (phone, created_at desc);
create index trial_requests_ip_time on public.trial_requests (ip, created_at desc);

-- Chuẩn hoá + chống spam: số điện thoại 9–15 chữ số; trùng số trong 10 phút bỏ qua im lặng;
-- tối đa 5 yêu cầu / IP / giờ; khách không tự đặt trạng thái hay ghi chú.
create or replace function public.trial_requests_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  hdr json := nullif(current_setting('request.headers', true), '')::json;
  digits text;
begin
  new.phone := regexp_replace(coalesce(new.phone, ''), '[^+0-9]', '', 'g');
  digits := regexp_replace(new.phone, '\D', '', 'g');
  if char_length(digits) < 9 or char_length(digits) > 15 then
    raise exception 'error.trial.phone_invalid' using errcode = '22023';
  end if;
  new.full_name := btrim(new.full_name);
  new.company_name := btrim(new.company_name);
  new.email := nullif(btrim(coalesce(new.email, '')), '');
  new.status := 'NEW';
  new.admin_note := null;
  new.created_at := now();
  new.ip := split_part(coalesce(hdr ->> 'x-forwarded-for', hdr ->> 'cf-connecting-ip', ''), ',', 1);
  if new.ip <> '' and (select count(*) from public.trial_requests t
                        where t.ip = new.ip and t.created_at > now() - interval '1 hour') >= 5 then
    raise exception 'error.trial.too_many' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.trial_requests t
             where t.phone = new.phone and t.created_at > now() - interval '10 minutes') then
    return null;
  end if;
  return new;
end $$;
revoke all on function public.trial_requests_guard() from public, anon, authenticated;

create trigger trial_requests_guard before insert on public.trial_requests
  for each row execute function public.trial_requests_guard();

-- Trang công khai chỉ được THÊM, không đọc/sửa/xoá. Xem và xử lý trong Supabase Dashboard.
alter table public.trial_requests enable row level security;
revoke all on public.trial_requests from anon, authenticated;
grant insert (full_name, company_name, phone, email, company_size, need, consent, source)
  on public.trial_requests to anon;
create policy "landing_can_insert" on public.trial_requests
  for insert to anon with check (consent);
