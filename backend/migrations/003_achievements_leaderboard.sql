-- Warfront Mandate: achievements and the public leaderboard (owner request 2026-10-12).
-- Apply after 002_profiles_levels_deletion.sql.
--
-- Achievements are reported by the phone (single-player); only known ids are accepted, each
-- once per player. The leaderboard shows commander names, levels and win counts only — never
-- emails or account ids.
begin;

create table public.player_achievements (
  player_id uuid not null references auth.users(id) on delete cascade,
  achievement text not null,
  unlocked_at timestamptz not null default now(),
  primary key (player_id, achievement)
);
alter table public.player_achievements enable row level security;
revoke all on public.player_achievements from anon, authenticated;
grant select on public.player_achievements to authenticated;
create policy "Read own achievements" on public.player_achievements
for select to authenticated using (player_id = (select auth.uid()));

create function public.unlock_achievement(code text) returns boolean
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not (select private.has_confirmed_email()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if code not in ('first_blood', 'veteran', 'conqueror', 'capital_fall', 'annexer', 'first_victory',
                  'domination', 'economic', 'elimination', 'points', 'both_sides', 'peacemaker',
                  'coalition', 'strategist', 'builder', 'nuclear', 'shield') then
    raise exception 'unknown achievement' using errcode = '22023';
  end if;
  insert into public.player_achievements(player_id, achievement) values (auth.uid(), code)
  on conflict do nothing;
  return found;
end;
$$;
revoke all on function public.unlock_achievement(text) from public, anon;
grant execute on function public.unlock_achievement(text) to authenticated;

-- Top commanders by XP. Public fields only.
create function public.top_commanders(how_many integer default 50)
returns table (place bigint, commander_name text, level integer, xp bigint, wins integer)
language sql stable security definer set search_path = '' as $$
  select row_number() over (order by p.xp desc, p.wins desc, p.created_at),
         p.commander_name, public.commander_level(p.xp), p.xp, p.wins
  from public.player_profiles p
  join auth.users u on u.id = p.id and u.email_confirmed_at is not null
  order by p.xp desc, p.wins desc, p.created_at
  limit least(greatest(coalesce(how_many, 50), 1), 100)
$$;
revoke all on function public.top_commanders(integer) from public, anon;
grant execute on function public.top_commanders(integer) to authenticated;

commit;
