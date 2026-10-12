-- Run only against the dedicated project after all migrations. No emails are sent.
-- Assertions run in a transaction and all temporary users/matches are rolled back.
begin;
do $test$
declare a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid(); sid uuid:=gen_random_uuid(); m uuid; seq bigint; n integer;
begin
insert into auth.users(id,email,email_confirmed_at,raw_user_meta_data,role,aud)
values(a,a::text||'@example.invalid',now(),'{"commander_name":"TestAlpha"}','authenticated','authenticated'),
(b,b::text||'@example.invalid',now(),'{"commander_name":"TestBravo"}','authenticated','authenticated'),
(c,c::text||'@example.invalid',null,'{}','authenticated','authenticated');
if (select count(*) from public.player_profiles where id in(a,b,c))<>3 then raise exception 'signup trigger failed'; end if;
perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','session_id',sid)::text,true);
execute 'set local role authenticated';
select count(*) into n from public.player_profiles;
if n<>1 then raise exception 'profile isolation failed'; end if;
update public.player_profiles set commander_name='RenamedAlpha' where id=a;
begin
 update public.player_profiles set xp=100 where id=a;
 raise exception 'client xp accepted';
exception when insufficient_privilege then null; end;
begin
 perform public.server_create_match(a,'russia');
 raise exception 'client match control accepted';
exception when insufficient_privilege then null; end;
begin
 perform public.record_match_result(true,20);
 raise exception 'client reward accepted';
exception when insufficient_privilege then null; end;
begin
 perform public.delete_my_account();
 raise exception 'revoked session deletion accepted';
exception when insufficient_privilege then null; end;
perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated')::text,true);
select count(*) into n from public.player_profiles;
if n<>0 then raise exception 'unconfirmed profile visible'; end if;
execute 'reset role';
m:=public.server_create_match(a,'russia');
perform public.server_join_match(b,m,'ukraine');
perform public.server_start_match(m,'{"test_state":true}'::jsonb);
seq:=public.server_enqueue_order(a,m,sid,'move','{"unit_id":1}'::jsonb);
if public.server_enqueue_order(a,m,sid,'move','{"unit_id":1}'::jsonb)<>seq then raise exception 'order replay failed'; end if;
perform public.server_checkpoint(m,0,'{"test_state":2}'::jsonb,seq);
begin
 perform public.server_checkpoint(m,0,'{"test_state":3}'::jsonb,seq);
 raise exception 'stale checkpoint accepted';
exception when raise_exception then
 if sqlerrm<>'stale checkpoint' then raise; end if;
end;
perform public.server_finish_match(m,'russia',20);
perform public.server_finish_match(m,'russia',20);
if (select xp from public.player_profiles where id=a)<>120 or
   (select games_played from public.player_profiles where id=a)<>1 then raise exception 'award replay failed'; end if;
insert into auth.sessions(id,user_id,created_at,updated_at) values(sid,a,now(),now());
perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','session_id',sid)::text,true);
execute 'set local role authenticated';
perform public.delete_my_account();
execute 'reset role';
if exists(select 1 from auth.users where id=a) or exists(select 1 from public.player_profiles where id=a)
  or exists(select 1 from auth.sessions where user_id=a) then raise exception 'deletion failed'; end if;
if not exists(select 1 from auth.users where id=b) then raise exception 'other account deleted'; end if;
end $test$;
rollback;
select 'passed: profile isolation, unconfirmed denial, protected XP and match RPCs, session-required deletion, order replay, checkpoint guard, one-time awards, deletion cascades; test records rolled back' as result;