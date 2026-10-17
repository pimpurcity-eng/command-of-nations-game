-- Warfront Mandate: finishing the training match grants 10 XP once per commander
-- (owner 2026-10-17: "You have to have 10 experience points to join the Europe map").
-- Apply after 005_premium.sql.
--
-- The once-only record is the 'training_complete' achievement row, so repeated or replayed
-- calls (reinstalls, a second phone, a resumed training save) never add XP twice.
begin;

create function public.complete_training()
returns table (xp bigint, level integer, granted boolean)
language plpgsql security definer set search_path = '' as $$
declare me uuid := private.require_player(); fresh boolean;
begin
  insert into public.player_achievements(player_id, achievement)
  values (me, 'training_complete') on conflict do nothing;
  fresh := found;
  if fresh then
    update public.player_profiles p set xp = p.xp + 10 where p.id = me;
  end if;
  return query
    select p.xp, public.commander_level(p.xp), fresh from public.player_profiles p where p.id = me;
end;
$$;
revoke all on function public.complete_training() from public, anon;
grant execute on function public.complete_training() to authenticated;

commit;
