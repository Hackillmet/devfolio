-- DEVFOLIO: вставьте целиком в Supabase -> SQL Editor -> Run (можно запускать повторно после обновлений)
create table if not exists public.docs (
  col text not null,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (col, id)
);
alter table public.docs enable row level security;

-- Профили, избранное и отзывы видят все
drop policy if exists "public read" on public.docs;
create policy "public read" on public.docs for select
  using (col in ('profiles','stars','reviews','files'));
-- Личные настройки (прочитано/уведомления) видит только владелец
drop policy if exists "read own state" on public.docs;
create policy "read own state" on public.docs for select
  using (col = 'state' and id = auth.uid()::text);
-- Файлы сайтов проектов (id = автор:проект) видят все, пишет только автор
-- Переписку видят только двое участников (id = отправитель:получатель)
drop policy if exists "read own chats" on public.docs;
create policy "read own chats" on public.docs for select
  using (col = 'msgs' and (split_part(id,':',1) = auth.uid()::text or split_part(id,':',2) = auth.uid()::text));

-- Писать можно только в свои записи
drop policy if exists "insert own" on public.docs;
create policy "insert own" on public.docs for insert to authenticated
  with check ((col in ('profiles','stars','reviews','state') and id = auth.uid()::text)
           or (col in ('msgs','files') and split_part(id,':',1) = auth.uid()::text));
drop policy if exists "update own" on public.docs;
create policy "update own" on public.docs for update to authenticated
  using ((col in ('profiles','stars','reviews','state') and id = auth.uid()::text)
      or (col in ('msgs','files') and split_part(id,':',1) = auth.uid()::text))
  with check ((col in ('profiles','stars','reviews','state') and id = auth.uid()::text)
      or (col in ('msgs','files') and split_part(id,':',1) = auth.uid()::text));
drop policy if exists "delete own" on public.docs;
create policy "delete own" on public.docs for delete to authenticated
  using ((col in ('profiles','stars','reviews','state') and id = auth.uid()::text)
      or (col in ('msgs','files') and split_part(id,':',1) = auth.uid()::text));

-- Живые обновления (новые сообщения и профили без перезагрузки)
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;
