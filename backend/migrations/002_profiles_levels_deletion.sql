-- Command of Nations: commander levels, XP, match stats, and in-app account deletion.
-- Apply after 001_player_accounts.sql on the dedicated Command of Nations Supabase project.
--
-- Players never write XP or stats directly: they only call record_match_result(), which the
-- server rate-limits and caps. While matches are single-player against the AI the result is
-- reported by the phone; when shared online matches arrive, the match server records results
-- instead and this function's grant to `authenticated` is revoked.
begin;

alter table public.player_profiles
  add column xp bigint not null default 0 check (xp >= 0),
  add column games_played integer not null default 0 check (games_played >= 0),
  add column wins integer not null default 0 check (wins >= 0),
  add column losses integer not null default 0 check (losses >= 0),
  add column last_result_at timestamptz;

-- Level from XP: level n needs 100 * (n - 1)^2 XP (1: 0, 2: 100, 3: 400, 4: 900, ...).
-- Same formula in game/scripts/accounts/player_auth.gd (PlayerAuth.level_for).
create function public.commander_level(xp bigint) returns integer
language sql immutable as $$ select floor(sqrt(greatest(xp, 0) / 100.0))::integer + 1 $$;

-- Audit log of reported results (private; not readable through the Data API).
create table private.match_results (
  id bigserial primary key,
  player_id uuid not null references auth.users(id) on delete cascade,
  won boolean not null,
  minutes integer not null,
  xp_awarded integer not null,
  created_at timestamptz not null default now()
);

-- One result per 10 minutes per player; XP: 100 for a win, 25 for a defeat, plus up to 50 for
-- match length. Returns the updated profile (xp, level, stats).
create function public.record_match_result(won boolean, minutes integer)
returns table (xp bigint, level integer, games_played integer, wins integer, losses integer)
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  last timestamptz;
  award integer;
begin
  if me is null or not (select private.has_confirmed_email()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select p.last_result_at into last from public.player_profiles p where p.id = me for update;
  if last is not null and last > now() - interval '10 minutes' then
    raise exception 'too soon' using errcode = 'P0001';
  end if;
  award := (case when won then 100 else 25 end) + least(greatest(coalesce(minutes, 0), 0), 50);
  insert into private.match_results(player_id, won, minutes, xp_awarded)
    values (me, won, least(greatest(coalesce(minutes, 0), 0), 100000), award);
  return query
  update public.player_profiles p set
    xp = p.xp + award,
    games_played = p.games_played + 1,
    wins = p.wins + (case when won then 1 else 0 end),
    losses = p.losses + (case when won then 0 else 1 end),
    last_result_at = now()
  where p.id = me
  returning p.xp, public.commander_level(p.xp), p.games_played, p.wins, p.losses;
end;
$$;
revoke all on function public.record_match_result(boolean, integer) from public, anon;
grant execute on function public.record_match_result(boolean, integer) to authenticated;

-- Google Play requires apps with accounts to offer deletion in the app and on the web.
-- Deletes the caller's auth user; the profile and match log go with it (on delete cascade).
create function public.delete_my_account() returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;
revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- Players may read the new columns of their own profile (row policy from migration 001).
grant select (xp, games_played, wins, losses, last_result_at) on public.player_profiles to authenticated;

commit;
