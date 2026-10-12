-- Warfront Mandate: server-only lobbies, ordered commands and durable checkpoints.
-- Apply after 001 and 002. No client may declare wins or write match state.
begin;
revoke execute on function public.record_match_result(boolean, integer) from authenticated;

create table private.online_matches (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  status text not null default 'waiting' check (status in ('waiting','running','finished')),
  revision bigint not null default 0,
  applied_sequence bigint not null default 0,
  next_sequence bigint not null default 1,
  snapshot jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create table private.online_players (
  match_id uuid references private.online_matches(id) on delete cascade,
  player_id uuid references auth.users(id) on delete set null,
  country text not null check (country in ('russia','ukraine')),
  primary key (match_id,country),
  unique (match_id,player_id)
);
create table private.online_commands (
  match_id uuid references private.online_matches(id) on delete cascade,
  sequence bigint not null,
  player_id uuid references auth.users(id) on delete set null,
  request_id uuid not null,
  kind text not null check (kind in ('move','research','produce')),
  payload jsonb not null check (octet_length(payload::text) <= 8192),
  created_at timestamptz not null default now(),
  primary key(match_id,sequence), unique(match_id,player_id,request_id)
);
create table private.verified_match_awards (
  match_id uuid references private.online_matches(id) on delete cascade,
  player_id uuid references auth.users(id) on delete cascade,
  xp integer not null,
  primary key(match_id,player_id)
);
revoke all on private.online_matches, private.online_players,
  private.online_commands, private.verified_match_awards from public,anon,authenticated;
alter table private.online_matches enable row level security;
alter table private.online_players enable row level security;
alter table private.online_commands enable row level security;
alter table private.verified_match_awards enable row level security;

create function private.require_online_player(actor uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from auth.users where id=actor and email_confirmed_at is not null) then
    raise exception 'not allowed' using errcode='42501';
  end if;
end $$;
revoke all on function private.require_online_player(uuid) from public,anon,authenticated;

create function public.server_create_match(actor uuid, country text) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
  perform private.require_online_player(actor);
  -- Serialize lobby creation per player, so the limit holds under concurrent requests.
  perform 1 from public.player_profiles where id=actor for update;
  if (select count(*) from private.online_matches where owner_id=actor and status!='finished') >= 3 then
    raise exception 'lobby limit';
  end if;
  insert into private.online_matches(owner_id) values(actor) returning id into result;
  insert into private.online_players values(result,actor,country);
  return result;
end $$;

create function public.server_join_match(actor uuid, target uuid, country text) returns void
language plpgsql security definer set search_path='' as $$
declare state text;
begin
  perform private.require_online_player(actor);
  select status into state from private.online_matches where id=target for update;
  if state is distinct from 'waiting' then raise exception 'lobby unavailable'; end if;
  insert into private.online_players values(target,actor,country);
end $$;

create function public.server_match_info(actor uuid, target uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  perform private.require_online_player(actor);
  if not exists(select 1 from private.online_players where match_id=target and player_id=actor) then
    raise exception 'not allowed' using errcode='42501';
  end if;
  -- Never expose raw snapshots: the worker must implement country-specific fog of war.
  return (select jsonb_build_object('id',m.id,'status',m.status,'revision',m.revision,
    'country',(select country from private.online_players where match_id=target and player_id=actor),
    'players',(select count(*) from private.online_players where match_id=target and player_id is not null))
    from private.online_matches m where m.id=target);
end $$;

create function public.server_enqueue_order(actor uuid, target uuid, request uuid, kind text, payload jsonb)
returns bigint language plpgsql security definer set search_path='' as $$
declare state text; result bigint;
begin
  perform private.require_online_player(actor);
  select status into state from private.online_matches where id=target for update;
  if not exists(select 1 from private.online_players where match_id=target and player_id=actor) then
    raise exception 'not allowed' using errcode='42501';
  end if;
  select sequence into result from private.online_commands
    where match_id=target and player_id=actor and request_id=request;
  if result is not null then return result; end if;
  if state is distinct from 'running' then raise exception 'match not running'; end if;
  -- Payload admission is not simulation authorization. The worker must validate ownership,
  -- terrain, prerequisites, balances and timing before applying any command.
  update private.online_matches set next_sequence=next_sequence+1 where id=target
    returning next_sequence-1 into result;
  insert into private.online_commands values(target,result,actor,request,kind,payload,now());
  return result;
end $$;

create function public.server_checkpoint(target uuid, expected_revision bigint, state jsonb, through_sequence bigint)
returns bigint language plpgsql security definer set search_path='' as $$
declare result bigint;
begin
  if jsonb_typeof(state) is distinct from 'object' or octet_length(state::text)>16777216 then
    raise exception 'invalid checkpoint';
  end if;
  update private.online_matches set snapshot=state,revision=revision+1,applied_sequence=through_sequence
    where id=target and revision=expected_revision and status='running'
      and through_sequence>=applied_sequence and through_sequence<next_sequence
    returning revision into result;
  if result is null then raise exception 'stale checkpoint'; end if;
  return result;
end $$;

-- Only a trusted simulation worker can start or finish matches. No player-facing route
-- exists for these operations. This migration does not implement the Godot simulation.
create function public.server_finish_match(target uuid, winning_country text, played_minutes integer)
returns void language plpgsql security definer set search_path='' as $$
declare state text; p record; award integer;
begin
  if winning_country is null or winning_country not in ('russia','ukraine') or played_minutes<0 or played_minutes is null then
    raise exception 'invalid result';
  end if;
  select status into state from private.online_matches where id=target for update;
  if state='finished' then return; end if;
  if state is distinct from 'running' then raise exception 'match not running'; end if;
  for p in select * from private.online_players where match_id=target and player_id is not null loop
    award := (case when p.country=winning_country then 100 else 25 end)+least(played_minutes,50);
    insert into private.verified_match_awards values(target,p.player_id,award);
    update public.player_profiles set xp=xp+award,games_played=games_played+1,
      wins=wins+(case when p.country=winning_country then 1 else 0 end),
      losses=losses+(case when p.country=winning_country then 0 else 1 end),last_result_at=now()
      where id=p.player_id;
  end loop;
  update private.online_matches set status='finished' where id=target;
end $$;

create function public.server_start_match(target uuid, initial_state jsonb) returns void
language plpgsql security definer set search_path='' as $$
begin
  perform 1 from private.online_matches where id=target for update;
  if jsonb_typeof(initial_state) is distinct from 'object' or initial_state='{}'::jsonb
      or octet_length(initial_state::text)>16777216 then raise exception 'invalid initial state'; end if;
  if (select count(*) from private.online_players p join auth.users u on u.id=p.player_id
      where p.match_id=target and u.email_confirmed_at is not null)!=2 then
    raise exception 'two confirmed players required';
  end if;
  update private.online_matches set status='running',snapshot=initial_state where id=target and status='waiting';
  if not found then raise exception 'lobby unavailable'; end if;
end $$;

create function public.server_restore_match(target uuid) returns jsonb
language sql security definer set search_path='' as $$
  select jsonb_build_object('id',m.id,'status',m.status,'revision',m.revision,
    'applied_sequence',m.applied_sequence,'snapshot',m.snapshot,
    'players',coalesce((select jsonb_agg(jsonb_build_object('id',p.player_id,'country',p.country))
      from private.online_players p where p.match_id=m.id),'[]'::jsonb),
    'pending_commands',coalesce((select jsonb_agg(to_jsonb(c) order by c.sequence)
      from private.online_commands c where c.match_id=m.id and c.sequence>m.applied_sequence),'[]'::jsonb))
  from private.online_matches m where m.id=target
$$;

revoke all on function public.server_create_match(uuid,text), public.server_join_match(uuid,uuid,text),
  public.server_match_info(uuid,uuid),public.server_enqueue_order(uuid,uuid,uuid,text,jsonb),
  public.server_checkpoint(uuid,bigint,jsonb,bigint),public.server_finish_match(uuid,text,integer),
  public.server_start_match(uuid,jsonb),public.server_restore_match(uuid)
  from public,anon,authenticated;
grant execute on function public.server_create_match(uuid,text), public.server_join_match(uuid,uuid,text),
  public.server_match_info(uuid,uuid),public.server_enqueue_order(uuid,uuid,uuid,text,jsonb),
  public.server_checkpoint(uuid,bigint,jsonb,bigint),public.server_finish_match(uuid,text,integer),
  public.server_start_match(uuid,jsonb),public.server_restore_match(uuid)
  to service_role;
commit;
