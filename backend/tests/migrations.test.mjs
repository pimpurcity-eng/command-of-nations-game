import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const { PGlite } = await import(process.env.WM_TEST_PGLITE || '@electric-sql/pglite');
const a = '11111111-1111-4111-8111-111111111111';
const b = '22222222-2222-4222-8222-222222222222';
const outsider = '33333333-3333-4333-8333-333333333333';
const unconfirmed = '44444444-4444-4444-8444-444444444444';
const requestId = '55555555-5555-4555-8555-555555555555';

test('Server-only match persistence, permissions, replay protection and restart recovery', async t => {
  const directory = await mkdtemp(join(tmpdir(), 'wm-db-'));
  let db = new PGlite(directory);
  try {
    // Provider stand-ins only: a real PostgreSQL engine, not a live Supabase service.
    await db.exec(`create role anon; create role authenticated; create role service_role;
      create schema auth; create table auth.users(id uuid primary key,
        email_confirmed_at timestamptz,raw_user_meta_data jsonb default '{}');
      create function auth.uid() returns uuid language sql stable as $$
        select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
      grant usage on schema auth to authenticated; grant execute on function auth.uid() to authenticated;`);
    for (const name of ['001_player_accounts.sql','002_profiles_levels_deletion.sql','003_server_owned_matches.sql'])
      await db.exec(await readFile(new URL(`../migrations/${name}`, import.meta.url), 'utf8'));
    for (const id of [a,b,outsider,unconfirmed]) await db.query(
      'insert into auth.users(id,email_confirmed_at) values($1,$2)', [id,id===unconfirmed?null:'2026-10-12T00:00:00Z']);
    const call = async (sql, params=[]) => (await db.query(sql,params)).rows[0]?.value;
    const create = id => call('select public.server_create_match($1,$2) as value',[id,'russia']);
    let match;
    await t.test('Unconfirmed players cannot create lobbies', async () => {
      await assert.rejects(create(unconfirmed), /not allowed/);
      match = await create(a);
    });
    await t.test('Players cannot use privileged functions or submit self-reported XP', async () => {
      await db.exec('set role authenticated');
      await assert.rejects(create(a), /permission denied/);
      await assert.rejects(db.query('select public.record_match_result(true,30)'), /permission denied/);
      await assert.rejects(db.query('select * from private.online_matches'), /permission denied/);
      await assert.rejects(db.query('update public.player_profiles set xp=9999'), /permission denied/);
      await db.exec('reset role');
    });
    await t.test('Own-profile RLS prevents reading other commanders', async () => {
      await db.query("select set_config('request.jwt.claim.sub',$1,false)",[a]);
      await db.exec('set role authenticated');
      const rows=(await db.query('select id from public.player_profiles')).rows;
      assert.deepEqual(rows.map(row=>row.id),[a]);
      await db.exec('reset role');
    });
    await t.test('Country slots and player membership cannot be duplicated', async () => {
      await assert.rejects(db.query('select public.server_join_match($1,$2,$3)',[b,match,'russia']), /duplicate key/);
      await db.query('select public.server_join_match($1,$2,$3)',[b,match,'ukraine']);
      await assert.rejects(db.query('select public.server_join_match($1,$2,$3)',[a,match,'ukraine']), /duplicate key/);
    });
    await t.test('Metadata hides raw snapshots and refuses outsiders', async () => {
      const info=await call('select public.server_match_info($1,$2) as value',[a,match]);
      assert.equal(info.players,2);assert.equal(info.country,'russia');assert.equal(info.snapshot,undefined);
      await assert.rejects(db.query('select public.server_match_info($1,$2)',[outsider,match]), /not allowed/);
    });
    const enqueue=(actor,request=requestId)=>call('select public.server_enqueue_order($1,$2,$3,$4,$5) as value',
      [actor,match,request,'move',{unit_id:'unit-1',destination:{x:1,z:2}}]);
    await t.test('Orders wait for a worker-started match', async () => {
      await assert.rejects(enqueue(a), /match not running/);
      await db.query('select public.server_start_match($1,$2)',[match,{clock:0,units:[]}]);
      await assert.rejects(enqueue(outsider), /not allowed/);
    });
    await t.test('An order retry returns the same sequence and inserts only once', async () => {
      assert.equal(Number(await enqueue(a)),1);assert.equal(Number(await enqueue(a)),1);
      assert.equal(Number(await call('select count(*) as value from private.online_commands')),1);
      assert.equal(Number(await enqueue(b)),2);
    });
    await t.test('Checkpoint revision guards and command sequence guards prevent stale writes', async () => {
      assert.equal(Number(await call('select public.server_checkpoint($1,$2,$3,$4) as value',
        [match,0,{clock:100,units:[]},1])),1);
      await assert.rejects(db.query('select public.server_checkpoint($1,$2,$3,$4)',
        [match,0,{clock:0},1]), /stale checkpoint/);
      await assert.rejects(db.query('select public.server_checkpoint($1,$2,$3,$4)',
        [match,1,{clock:100},999]), /stale checkpoint/);
    });
    await t.test('Restart restores checkpoint and pending orders in sequence', async () => {
      await db.close();db=new PGlite(directory);
      const restored=await call('select public.server_restore_match($1) as value',[match]);
      assert.equal(restored.snapshot.clock,100);assert.equal(Number(restored.revision),1);
      assert.deepEqual(restored.pending_commands.map(c=>Number(c.sequence)),[2]);
    });
    await t.test('Results must have a valid winner; duplicate finalization cannot award twice', async () => {
      await assert.rejects(db.query('select public.server_finish_match($1,$2,$3)',[match,null,20]), /invalid result/);
      await db.query('select public.server_finish_match($1,$2,$3)',[match,'russia',20]);
      await db.query('select public.server_finish_match($1,$2,$3)',[match,'ukraine',50]);
      const rows=(await db.query('select id,xp,games_played,wins,losses from public.player_profiles where id in ($1,$2) order by id',[a,b])).rows;
      assert.equal(Number(rows[0].xp),120);assert.equal(rows[0].games_played,1);assert.equal(rows[0].wins,1);
      assert.equal(Number(rows[1].xp),45);assert.equal(rows[1].losses,1);
      await assert.rejects(enqueue(a,'66666666-6666-4666-8666-666666666666'), /match not running/);
    });
    await t.test('Lobby limit is enforced', async () => {
      await create(a);await create(a);await create(a);await assert.rejects(create(a), /lobby limit/);
    });
    await t.test('Account deletion removes profile and rewards while preserving shared match', async () => {
      await db.query("select set_config('request.jwt.claim.sub',$1,false)",[a]);
      await db.exec('set role authenticated');await db.query('select public.delete_my_account()');await db.exec('reset role');
      assert.equal(Number(await call('select count(*) as value from public.player_profiles where id=$1',[a])),0);
      assert.equal(Number(await call('select count(*) as value from private.verified_match_awards where player_id=$1',[a])),0);
      assert.equal(Number(await call('select count(*) as value from private.online_matches where id=$1',[match])),1);
    });
  } finally { await db.close();await rm(directory,{recursive:true,force:true}); }
});
