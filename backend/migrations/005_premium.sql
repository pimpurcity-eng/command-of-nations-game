-- Warfront Mandate: Premium membership flag on the commander profile.
-- Owner 2026-10-16: "For premium account, I want you to start creating the premium account."
-- Apply after 004_stats_alliances.sql (Supabase dashboard -> SQL Editor -> paste -> Run).
-- Design: docs/PREMIUM.md. Rally points and the five-unit city queue stay free for everyone.
--
-- premium_until: the membership is active while premium_until > now(). null = never had it.
--   * Players READ it on their own profile (table select grant and row policy from 001).
--   * Players NEVER write it: 001 only grants update (commander_name). Only the server
--     (service role: SQL Editor, an Edge Function, or the future Google Play purchase webhook)
--     changes it, through private.grant_premium() below, which also keeps an audit log.
begin;

alter table public.player_profiles
  add column premium_until timestamptz;

-- Readable by the owner of the profile (the row policy from 001 still limits rows to their own).
grant select (premium_until) on public.player_profiles to authenticated;
-- Belt and braces: no client role may write it, whatever later grants are added.
revoke insert, update (premium_until) on public.player_profiles from anon, authenticated;

-- Audit log of every grant or extension (private; not readable through the Data API).
create table private.premium_grants (
  id bigserial primary key,
  player_id uuid not null references auth.users(id) on delete cascade,
  days integer not null,
  source text not null,          -- e.g. 'google_play', 'owner', 'promo'
  reference text,                -- e.g. the Google Play order id (never a purchase token)
  premium_until timestamptz not null,
  created_at timestamptz not null default now()
);

-- Adds days of Premium (extends from the current end if still active). Server only.
create function private.grant_premium(player uuid, days integer, source text, reference text default null)
returns timestamptz
language plpgsql security definer set search_path = '' as $$
declare
  ends timestamptz;
begin
  if days is null or days < 1 or days > 400 then
    raise exception 'days must be 1-400' using errcode = '22023';
  end if;
  update public.player_profiles p
     set premium_until = greatest(coalesce(p.premium_until, now()), now()) + make_interval(days => days)
   where p.id = player
  returning p.premium_until into ends;
  if ends is null then
    raise exception 'no such commander' using errcode = 'P0002';
  end if;
  insert into private.premium_grants(player_id, days, source, reference, premium_until)
    values (player, days, coalesce(source, 'unknown'), reference, ends);
  return ends;
end;
$$;
revoke all on function private.grant_premium(uuid, integer, text, text) from public, anon, authenticated;
grant execute on function private.grant_premium(uuid, integer, text, text) to service_role;

commit;

-- Owner test (SQL Editor, runs as the service role): give a commander 30 days of Premium.
--   select private.grant_premium(
--     (select id from public.player_profiles where commander_name = 'Your_Name'), 30, 'owner');
-- End it early:
--   update public.player_profiles set premium_until = now() where commander_name = 'Your_Name';
