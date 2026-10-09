-- Apply to a dedicated Command of Nations Supabase project.
begin;
create table public.player_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  commander_name text not null check (commander_name ~ '^[A-Za-z0-9_]{3,24}$'),
  created_at timestamptz not null default now()
);
alter table public.player_profiles enable row level security;
revoke all on public.player_profiles from anon, authenticated;
grant select on public.player_profiles to authenticated;
grant update (commander_name) on public.player_profiles to authenticated;
-- Check confirmation against Auth, never against client-editable metadata.
create schema if not exists private;
create function private.has_confirmed_email() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from auth.users where id = auth.uid() and email_confirmed_at is not null)
$$;
revoke all on function private.has_confirmed_email() from public;
grant usage on schema private to authenticated;
grant execute on function private.has_confirmed_email() to authenticated;
create policy "Read own confirmed profile" on public.player_profiles
for select to authenticated using (id=(select auth.uid()) and (select private.has_confirmed_email()));
create policy "Rename own confirmed commander" on public.player_profiles
for update to authenticated using (id=(select auth.uid()) and (select private.has_confirmed_email()))
with check (id=(select auth.uid()) and (select private.has_confirmed_email()));
create function private.create_commander_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
declare requested_name text;
begin
  requested_name := new.raw_user_meta_data->>'commander_name';
  if requested_name is null or requested_name !~ '^[A-Za-z0-9_]{3,24}$' then
    requested_name := 'Commander_' || substr(replace(new.id::text, '-', ''),1,8);
  end if;
  insert into public.player_profiles(id,commander_name) values(new.id,requested_name);
  return new;
end;
$$;
revoke all on function private.create_commander_profile() from public;
create trigger on_player_signup after insert on auth.users
for each row execute function private.create_commander_profile();
-- No client-writable role, currency, combat or match state is introduced.
commit;
