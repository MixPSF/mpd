-- Удаляем старую таблицу, если она создана
drop table if exists public.pipes_simple cascade;
drop function if exists public.current_shift_date();
drop function if exists public.current_shift_type();

-- 1. Функция определения даты смены (смена начинается в 08:00)
create or replace function public.current_shift_date() returns date
language sql stable as $$
  select ((now() at time zone 'Europe/Kyiv') - interval '8 hours')::date
$$;

-- 2. Функция определения типа смены: D (Дневная 08:00-20:00) или N (Ночная 20:00-08:00)
create or replace function public.current_shift_type() returns text
language sql stable as $$
  select case 
    when extract(hour from (now() at time zone 'Europe/Kyiv')) between 8 and 19 then 'D'
    else 'N'
  end
$$;

-- 3. Создание таблицы труб
create table public.pipes_simple (
  id uuid primary key default gen_random_uuid(),
  pipe_number text not null,
  shift_date date not null default public.current_shift_date(),
  shift_type text not null default public.current_shift_type() check (shift_type in ('D','N')),
  mpd1_val text not null default '-' check (mpd1_val in ('-','N','Н','В','ЗАК')),
  mpd2_val text not null default '-' check (mpd2_val in ('-','N','Н','В','ЗАК')),
  mpd1_at timestamptz,
  mpd2_at timestamptz,
  created_at timestamptz not null default now(),
  unique (pipe_number, shift_date, shift_type)
);

create index idx_pipes_shift on public.pipes_simple (shift_date, shift_type, created_at desc);

-- 4. Автоматическое проставление времени отметки (сбрасывается при возврате в "-")
create or replace function public.stamp_mpd() returns trigger
language plpgsql as $$
begin
  if new.mpd1_val is distinct from old.mpd1_val then
    new.mpd1_at := case when new.mpd1_val = '-' then null else now() end;
  end if;
  if new.mpd2_val is distinct from old.mpd2_val then
    new.mpd2_at := case when new.mpd2_val = '-' then null else now() end;
  end if;
  return new;
end $$;

create trigger trg_stamp_mpd before update on public.pipes_simple
  for each row execute function public.stamp_mpd();

-- 5. Настройки RLS (прав доступа)
alter table public.pipes_simple enable row level security;
create policy "read"   on public.pipes_simple for select to anon using (true);
create policy "insert" on public.pipes_simple for insert to anon with check (true);
create policy "update" on public.pipes_simple for update to anon using (true) with check (true);
create policy "delete" on public.pipes_simple for delete to anon using (true);

-- 6. Включение Realtime
alter publication supabase_realtime add table public.pipes_simple;
