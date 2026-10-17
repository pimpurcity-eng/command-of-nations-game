-- Authoritative, read-only multiplayer eligibility. Apply after 006_training_xp.sql.
begin;
create or replace function public.multiplayer_access()
returns table (xp bigint, level integer, training_complete boolean)
language sql stable security invoker set search_path = '' as $$
  select p.xp, public.commander_level(p.xp), exists (
    select 1 from public.player_achievements a
    where a.player_id = auth.uid() and a.achievement = 'training_complete'
  )
  from public.player_profiles p where p.id = auth.uid();
$$;
revoke all on function public.multiplayer_access() from public, anon;
grant execute on function public.multiplayer_access() to authenticated;
commit;
