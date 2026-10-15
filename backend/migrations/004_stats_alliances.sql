-- Warfront Mandate: fuller commander statistics, more leaderboards and alliances.
-- Owner 2026-10-15: "Make sure profile keeps track of player stats and have top commander lists.
-- Also create an alliance outside of the matches like Call of War but make it much better."
-- Apply after 003_achievements_leaderboard.sql (Supabase dashboard -> SQL Editor -> paste -> Run).
--
-- Design (what makes it easier than Call of War alliances):
--   * One alliance per commander, joined in one tap (open alliances) or by request (approval).
--   * Roles: leader, officer, member. Officers approve requests and remove members; the leader
--     promotes, demotes and hands over leadership. A leader who leaves passes it on automatically.
--   * Alliance chat inside the game, kept for every member.
--   * Operations: an officer posts an online match code with the side to play; every member
--     sees it at the top of the alliance screen and joins with one tap. No lobbies to arrange.
--   * Alliance ranking by the members' combined XP and wins; the alliance tag shows on the
--     leaderboards.
-- Players never write tables directly: every change goes through the functions below, which
-- check the caller's role. Commanders are shown by commander name only, never email or user id.
begin;

-- ---------------------------------------------------------------- commander statistics
alter table public.player_profiles
  add column units_destroyed integer not null default 0 check (units_destroyed >= 0),
  add column units_lost integer not null default 0 check (units_lost >= 0),
  add column cities_captured integer not null default 0 check (cities_captured >= 0),
  add column play_minutes integer not null default 0 check (play_minutes >= 0),
  add column best_streak integer not null default 0 check (best_streak >= 0),
  add column current_streak integer not null default 0 check (current_streak >= 0);

alter table private.match_results
  add column units_destroyed integer not null default 0,
  add column units_lost integer not null default 0,
  add column cities_captured integer not null default 0;

-- record_match_result with the battle numbers. Same 10-minute rate limit and XP caps as before;
-- each number is capped so a modified client cannot inflate the boards.
create function public.record_match_stats(won boolean, minutes integer, destroyed integer, lost integer, cities integer)
returns table (xp bigint, level integer, games_played integer, wins integer, losses integer)
language plpgsql security definer set search_path = '' as $$
declare
  me uuid := auth.uid();
  last timestamptz;
  award integer;
  played integer := least(greatest(coalesce(minutes, 0), 0), 100000);
  killed integer := least(greatest(coalesce(destroyed, 0), 0), 2000);
  fallen integer := least(greatest(coalesce(lost, 0), 0), 2000);
  taken integer := least(greatest(coalesce(cities, 0), 0), 200);
begin
  if me is null or not (select private.has_confirmed_email()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select p.last_result_at into last from public.player_profiles p where p.id = me for update;
  if last is not null and last > now() - interval '10 minutes' then
    raise exception 'too soon' using errcode = 'P0001';
  end if;
  award := (case when won then 100 else 25 end) + least(played, 50) + least(killed, 50) + least(taken * 5, 50);
  insert into private.match_results(player_id, won, minutes, xp_awarded, units_destroyed, units_lost, cities_captured)
    values (me, won, played, award, killed, fallen, taken);
  return query
  update public.player_profiles p set
    xp = p.xp + award,
    games_played = p.games_played + 1,
    wins = p.wins + (case when won then 1 else 0 end),
    losses = p.losses + (case when won then 0 else 1 end),
    units_destroyed = p.units_destroyed + killed,
    units_lost = p.units_lost + fallen,
    cities_captured = p.cities_captured + taken,
    play_minutes = p.play_minutes + played,
    current_streak = case when won then p.current_streak + 1 else 0 end,
    best_streak = greatest(p.best_streak, case when won then p.current_streak + 1 else 0 end),
    last_result_at = now()
  where p.id = me
  returning p.xp, public.commander_level(p.xp), p.games_played, p.wins, p.losses;
end;
$$;
revoke all on function public.record_match_stats(boolean, integer, integer, integer, integer) from public, anon;
grant execute on function public.record_match_stats(boolean, integer, integer, integer, integer) to authenticated;

-- ---------------------------------------------------------------- alliances
create table public.alliances (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 3 and 28 and name ~ '^[A-Za-z0-9 _.-]+$'),
  tag text not null check (tag ~ '^[A-Z0-9]{2,4}$'),
  motto text not null default '' check (char_length(motto) <= 120),
  colour text not null default '#d9a441' check (colour ~ '^#[0-9a-fA-F]{6}$'),
  open boolean not null default true,
  operations_won integer not null default 0,
  created_at timestamptz not null default now()
);
create unique index alliances_name_key on public.alliances (lower(name));
create unique index alliances_tag_key on public.alliances (tag);

create table public.alliance_members (
  id bigint generated always as identity primary key,
  alliance_id uuid not null references public.alliances(id) on delete cascade,
  player_id uuid not null unique references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('leader', 'officer', 'member')),
  joined_at timestamptz not null default now()
);
create index alliance_members_alliance on public.alliance_members (alliance_id);

create table public.alliance_requests (
  id bigint generated always as identity primary key,
  alliance_id uuid not null references public.alliances(id) on delete cascade,
  player_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (alliance_id, player_id)
);

create table public.alliance_messages (
  id bigint generated always as identity primary key,
  alliance_id uuid not null references public.alliances(id) on delete cascade,
  player_id uuid references auth.users(id) on delete set null,
  body text not null check (char_length(body) between 1 and 400),
  created_at timestamptz not null default now()
);
create index alliance_messages_recent on public.alliance_messages (alliance_id, id desc);

create table public.alliance_operations (
  id bigint generated always as identity primary key,
  alliance_id uuid not null references public.alliances(id) on delete cascade,
  match_code text not null check (match_code ~ '^[A-Za-z0-9_-]{3,40}$'),
  side text not null check (side in ('russia', 'ukraine')),
  note text not null default '' check (char_length(note) <= 120),
  posted_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '48 hours'
);

-- Only the functions below touch these tables.
alter table public.alliances enable row level security;
alter table public.alliance_members enable row level security;
alter table public.alliance_requests enable row level security;
alter table public.alliance_messages enable row level security;
alter table public.alliance_operations enable row level security;
revoke all on public.alliances, public.alliance_members, public.alliance_requests, public.alliance_messages, public.alliance_operations from anon, authenticated;

create function private.require_player() returns uuid
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null or not (select private.has_confirmed_email()) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  return auth.uid();
end;
$$;

create function private.my_membership(out alliance uuid, out role text)
language sql stable security definer set search_path = '' as $$
  select m.alliance_id, m.role from public.alliance_members m where m.player_id = auth.uid()
$$;

create function public.create_alliance(alliance_name text, alliance_tag text, alliance_motto text default '', alliance_colour text default '#d9a441', is_open boolean default true)
returns uuid language plpgsql security definer set search_path = '' as $$
declare me uuid := private.require_player(); made uuid;
begin
  if exists (select 1 from public.alliance_members where player_id = me) then
    raise exception 'leave your alliance first' using errcode = 'P0001';
  end if;
  insert into public.alliances(name, tag, motto, colour, open)
    values (trim(alliance_name), upper(trim(alliance_tag)), coalesce(trim(alliance_motto), ''), coalesce(alliance_colour, '#d9a441'), coalesce(is_open, true))
    returning id into made;
  insert into public.alliance_members(alliance_id, player_id, role) values (made, me, 'leader');
  delete from public.alliance_requests where player_id = me;
  return made;
end;
$$;

-- Directory and ranking: combined XP and wins of the members.
create function public.alliance_directory(search text default '', how_many integer default 30)
returns table (alliance_id uuid, place bigint, name text, tag text, motto text, colour text, open boolean, members bigint, xp bigint, wins bigint, operations_won integer)
language sql stable security definer set search_path = '' as $$
  with totals as (
    select a.id, a.name, a.tag, a.motto, a.colour, a.open, a.operations_won,
           count(m.id) as members, coalesce(sum(p.xp), 0)::bigint as xp, coalesce(sum(p.wins), 0)::bigint as wins
    from public.alliances a
    left join public.alliance_members m on m.alliance_id = a.id
    left join public.player_profiles p on p.id = m.player_id
    group by a.id
  )
  select t.id, row_number() over (order by t.xp desc, t.wins desc, t.name), t.name, t.tag, t.motto, t.colour, t.open, t.members, t.xp, t.wins, t.operations_won
  from totals t
  where coalesce(search, '') = '' or t.name ilike '%' || search || '%' or t.tag ilike '%' || search || '%'
  order by t.xp desc, t.wins desc, t.name
  limit least(greatest(coalesce(how_many, 30), 1), 100)
$$;

create function public.join_alliance(target uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare me uuid := private.require_player(); is_open boolean; size integer;
begin
  if exists (select 1 from public.alliance_members where player_id = me) then
    raise exception 'leave your alliance first' using errcode = 'P0001';
  end if;
  select a.open into is_open from public.alliances a where a.id = target;
  if is_open is null then raise exception 'no such alliance' using errcode = 'P0001'; end if;
  select count(*) into size from public.alliance_members where alliance_id = target;
  if size >= 50 then raise exception 'alliance is full' using errcode = 'P0001'; end if;
  if is_open then
    insert into public.alliance_members(alliance_id, player_id) values (target, me);
    delete from public.alliance_requests where player_id = me;
    return 'joined';
  end if;
  insert into public.alliance_requests(alliance_id, player_id) values (target, me) on conflict do nothing;
  return 'requested';
end;
$$;

-- Everything the alliance screen shows, in one call.
create function public.my_alliance() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare me uuid := private.require_player(); mine record;
begin
  select * into mine from private.my_membership();
  if mine.alliance is null then return null; end if;
  return jsonb_build_object(
    'alliance', (select to_jsonb(a) - 'created_at' from public.alliances a where a.id = mine.alliance),
    'role', mine.role,
    'members', (select coalesce(jsonb_agg(jsonb_build_object('member_id', m.id, 'commander', p.commander_name, 'role', m.role,
                 'level', public.commander_level(p.xp), 'xp', p.xp, 'wins', p.wins, 'me', m.player_id = me)
                 order by case m.role when 'leader' then 0 when 'officer' then 1 else 2 end, p.xp desc), '[]'::jsonb)
                from public.alliance_members m join public.player_profiles p on p.id = m.player_id where m.alliance_id = mine.alliance),
    'requests', (select coalesce(jsonb_agg(jsonb_build_object('request_id', r.id, 'commander', p.commander_name, 'level', public.commander_level(p.xp))), '[]'::jsonb)
                 from public.alliance_requests r join public.player_profiles p on p.id = r.player_id
                 where r.alliance_id = mine.alliance and mine.role in ('leader', 'officer')),
    'operations', (select coalesce(jsonb_agg(jsonb_build_object('operation_id', o.id, 'match_code', o.match_code, 'side', o.side, 'note', o.note,
                   'posted_by', p.commander_name, 'created_at', o.created_at) order by o.id desc), '[]'::jsonb)
                   from public.alliance_operations o left join public.player_profiles p on p.id = o.posted_by
                   where o.alliance_id = mine.alliance and o.expires_at > now()),
    'messages', (select coalesce(jsonb_agg(x order by x.id), '[]'::jsonb) from (
                   select msg.id, coalesce(p.commander_name, 'former member') as commander, msg.body, msg.created_at
                   from public.alliance_messages msg left join public.player_profiles p on p.id = msg.player_id
                   where msg.alliance_id = mine.alliance order by msg.id desc limit 60) x));
end;
$$;

create function public.answer_alliance_request(request_id bigint, accept boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare mine record; req record;
begin
  perform private.require_player();
  select * into mine from private.my_membership();
  select * into req from public.alliance_requests r where r.id = request_id;
  if req is null or mine.alliance is distinct from req.alliance_id or mine.role not in ('leader', 'officer') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  delete from public.alliance_requests where id = request_id;
  if accept and not exists (select 1 from public.alliance_members where player_id = req.player_id)
     and (select count(*) from public.alliance_members where alliance_id = req.alliance_id) < 50 then
    insert into public.alliance_members(alliance_id, player_id) values (req.alliance_id, req.player_id);
    delete from public.alliance_requests where player_id = req.player_id;
  end if;
end;
$$;

-- Leader: promote/demote ('officer'/'member') or hand over ('leader'). Officers may only remove members.
create function public.set_alliance_role(member_id bigint, new_role text) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := private.require_player(); mine record; target record;
begin
  select * into mine from private.my_membership();
  select * into target from public.alliance_members m where m.id = member_id;
  if target is null or mine.alliance is distinct from target.alliance_id or mine.role <> 'leader' or target.player_id = me
     or new_role not in ('leader', 'officer', 'member') then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  if new_role = 'leader' then
    update public.alliance_members set role = 'officer' where player_id = me;
  end if;
  update public.alliance_members set role = new_role where id = member_id;
end;
$$;

create function public.remove_alliance_member(member_id bigint) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := private.require_player(); mine record; target record;
begin
  select * into mine from private.my_membership();
  select * into target from public.alliance_members m where m.id = member_id;
  if target is null or mine.alliance is distinct from target.alliance_id or target.player_id = me
     or not (mine.role = 'leader' or (mine.role = 'officer' and target.role = 'member')) then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  delete from public.alliance_members where id = member_id;
end;
$$;

-- Leaving: a leader hands over to the senior officer (or longest member); the last member
-- leaving closes the alliance.
create function public.leave_alliance() returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := private.require_player(); mine record; heir bigint;
begin
  select * into mine from private.my_membership();
  if mine.alliance is null then return; end if;
  delete from public.alliance_members where player_id = me;
  if not exists (select 1 from public.alliance_members where alliance_id = mine.alliance) then
    delete from public.alliances where id = mine.alliance;
  elsif mine.role = 'leader' then
    select m.id into heir from public.alliance_members m where m.alliance_id = mine.alliance
      order by case m.role when 'officer' then 0 else 1 end, m.joined_at limit 1;
    update public.alliance_members set role = 'leader' where id = heir;
  end if;
end;
$$;

create function public.update_alliance(alliance_motto text, alliance_colour text, is_open boolean) returns void
language plpgsql security definer set search_path = '' as $$
declare mine record;
begin
  perform private.require_player();
  select * into mine from private.my_membership();
  if mine.role is distinct from 'leader' then raise exception 'not allowed' using errcode = '42501'; end if;
  update public.alliances set motto = coalesce(trim(alliance_motto), motto), colour = coalesce(alliance_colour, colour), open = coalesce(is_open, open)
  where id = mine.alliance;
end;
$$;

create function public.post_alliance_message(message text) returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := private.require_player(); mine record; recent integer;
begin
  select * into mine from private.my_membership();
  if mine.alliance is null then raise exception 'not in an alliance' using errcode = 'P0001'; end if;
  select count(*) into recent from public.alliance_messages where player_id = me and created_at > now() - interval '1 minute';
  if recent >= 10 then raise exception 'slow down' using errcode = 'P0001'; end if;
  insert into public.alliance_messages(alliance_id, player_id, body) values (mine.alliance, me, trim(message));
  -- Keep the latest 500 messages per alliance.
  delete from public.alliance_messages where alliance_id = mine.alliance and id < (
    select id from public.alliance_messages where alliance_id = mine.alliance order by id desc offset 499 limit 1);
end;
$$;

create function public.post_alliance_operation(code text, play_side text, operation_note text default '') returns void
language plpgsql security definer set search_path = '' as $$
declare me uuid := private.require_player(); mine record;
begin
  select * into mine from private.my_membership();
  if mine.role not in ('leader', 'officer') then raise exception 'officers post operations' using errcode = '42501'; end if;
  insert into public.alliance_operations(alliance_id, match_code, side, note, posted_by)
    values (mine.alliance, code, play_side, coalesce(trim(operation_note), ''), me);
  delete from public.alliance_operations where alliance_id = mine.alliance and expires_at < now();
end;
$$;

-- More boards: by XP, wins, units destroyed, cities captured or best win streak. Alliance tag shown.
create function public.top_commanders_by(metric text default 'xp', how_many integer default 50)
returns table (place bigint, commander_name text, alliance_tag text, level integer, xp bigint, wins integer, units_destroyed integer, cities_captured integer, best_streak integer)
language sql stable security definer set search_path = '' as $$
  with ranked as (
    select p.*, a.tag,
      case coalesce(metric, 'xp') when 'wins' then p.wins::bigint when 'destroyed' then p.units_destroyed::bigint
        when 'cities' then p.cities_captured::bigint when 'streak' then p.best_streak::bigint else p.xp end as score
    from public.player_profiles p
    join auth.users u on u.id = p.id and u.email_confirmed_at is not null
    left join public.alliance_members m on m.player_id = p.id
    left join public.alliances a on a.id = m.alliance_id
  )
  select row_number() over (order by r.score desc, r.xp desc, r.created_at), r.commander_name, r.tag,
         public.commander_level(r.xp), r.xp, r.wins, r.units_destroyed, r.cities_captured, r.best_streak
  from ranked r
  order by r.score desc, r.xp desc, r.created_at
  limit least(greatest(coalesce(how_many, 50), 1), 100)
$$;

do $$
declare f text;
begin
  foreach f in array array['private.require_player()', 'private.my_membership()'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
  end loop;
  foreach f in array array[
    'public.create_alliance(text, text, text, text, boolean)', 'public.alliance_directory(text, integer)',
    'public.join_alliance(uuid)', 'public.my_alliance()', 'public.answer_alliance_request(bigint, boolean)',
    'public.set_alliance_role(bigint, text)', 'public.remove_alliance_member(bigint)', 'public.leave_alliance()',
    'public.update_alliance(text, text, boolean)', 'public.post_alliance_message(text)',
    'public.post_alliance_operation(text, text, text)', 'public.top_commanders_by(text, integer)'] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
-- The private helpers are called from the definer functions above (same owner).

commit;
