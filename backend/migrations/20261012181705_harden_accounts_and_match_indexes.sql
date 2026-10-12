begin;
alter function public.commander_level(bigint) set search_path = '';
alter table private.match_results enable row level security;
revoke all on private.match_results from public,anon,authenticated;
create index match_results_player_id_idx on private.match_results(player_id);
create index online_matches_owner_id_idx on private.online_matches(owner_id);
create index online_players_player_id_idx on private.online_players(player_id);
create index online_commands_player_id_idx on private.online_commands(player_id);
create index verified_match_awards_player_id_idx on private.verified_match_awards(player_id);
create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path='' as $$
declare me uuid := auth.uid(); session_claim text := auth.jwt()->>'session_id';
begin
  if me is null or session_claim is null or not exists(
    select 1 from auth.sessions s where s.id::text=session_claim and s.user_id=me
      and (s.not_after is null or s.not_after>now())
  ) then raise exception 'active session required' using errcode='42501'; end if;
  delete from auth.sessions where user_id=me;
  delete from auth.users where id=me;
end $$;
revoke all on function public.delete_my_account() from public,anon;
grant execute on function public.delete_my_account() to authenticated;
commit;
