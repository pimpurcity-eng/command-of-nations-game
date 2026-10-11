"""Import the owner's October 11 arsenal into the existing game; no APK build."""
import copy, hashlib, json, shutil, sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
incoming = Path(sys.argv[1]).resolve()
data = root / 'game/data'
assets = root / 'game/assets/library/arsenal'
assets.mkdir(parents=True, exist_ok=True)
catalog = json.loads((data / 'equipment.json').read_text())
roster = json.loads((data / 'asset_roster.json').read_text())
manifest = json.loads((root / 'docs/ARSENAL_ASSETS.json').read_text())
# European service does not change these models' American origin.
excluded = {'euro_f16am_belgium', 'euro_e7_wedgetail', 'euro_m113', 'euro_m270', 'euro_m270_mlrs'}
found = {}
for folder in sorted(incoming.iterdir()):
    if not folder.is_dir(): continue
    for path in folder.glob('*.glb'):
        if path.stem in excluded: continue
        # Revised ships win over the older package regardless of directory order.
        if path.name not in found or folder.name == 'ships_v3_russia_europe': found[path.name] = path
for name, path in found.items():
    shutil.copy2(path, assets / name)
    preview = path.with_suffix('.png')
    if preview.exists(): shutil.copy2(preview, assets / preview.name)
    manifest['models'][name] = hashlib.sha256(path.read_bytes()).hexdigest()

def tier(stem, name, **extra):
    assert stem + '.glb' in found, stem
    result = {'name': name, 'model': 'res://assets/library/arsenal/' + stem + '.glb', 'improvement': 'Supplied equipment'}
    if (assets / (stem + '.png')).exists(): result['preview'] = 'res://assets/library/arsenal/' + stem + '.png'
    result.update(extra)
    return result

def family(key, country, name, category, kind, tiers, role='', **extra):
    assert len(tiers) == 5
    spec = {'id': key, 'country': country, 'name': name, 'category': category, 'visual_kind': kind,
            'role': role or kind, 'asset_roster_id': key, 'seconds': 60,
            'cost': {'funds': 250, 'materials': 80, 'electronics': 40, 'fuel': 30, 'manpower': 30},
            'building_requirements': {'factory': 1}, 'research_days': [1,4,8,12,18],
            'research_tiers': tiers, 'model_status': 'Original supplied model'}
    spec.update(extra)
    catalog[:] = [s for s in catalog if s['id'] != key] + [spec]
    appearance = {k: v for k,v in tiers[0].items() if k in ['model','preview']}
    appearance.update(original_colors=True, temporary_recolor=False, source_model=tiers[0]['name'])
    entry = {'id': key, 'name': name, 'kind': kind, 'available_to': [country], 'shared_building': False,
             'assets': {'russian' if country == 'russia' else 'european': appearance}}
    roster[:] = [s for s in roster if s['id'] != key] + [entry]

family('fighters_russia','russia','Fighters','Fighters','fighter',[
    tier('russia_mig29smt','MiG-29SMT'),tier('russia_mig31bm','MiG-31BM'),tier('russia_su34','Su-34'),
    tier('russia_su35s','Su-35S'),tier('russia_su57','Su-57')],air_speed=3.2,air_range=14.0,air_damage=10.0,ground_damage=7.0,requires_airbase=True)
family('fighters_ukraine','ukraine','European fighters','Fighters','fighter',[
    tier('euro_mirage2000','Mirage 2000'),tier('euro_gripen_e','Gripen E'),tier('euro_gripen_e','Gripen E · sensors'),
    tier('euro_ngf_fcas','NGF / FCAS'),tier('euro_tempest_gcap','Tempest / GCAP')],air_speed=3.2,air_range=14.0,air_damage=10.0,ground_damage=7.0,requires_airbase=True)
for country,prefix,infantry in [
    ('russia','russia',[('motor_rifleman','Motor riflemen'),('naval_infantry','Naval infantry'),('vdv_paratrooper','VDV paratroopers'),('sniper','Snipers'),('spetsnaz','Spetsnaz')]),
    ('ukraine','euro',[('uk_royal_marine','Royal Marines'),('fr_foreign_legion','Foreign Legion'),('it_folgore_paratrooper','Folgore paratroopers'),('fi_winter_sniper','Winter snipers'),('de_ksk','KSK')])]:
    family('infantry_'+country,country,'Infantry','Infantry','infantry',[tier(prefix+'_'+s,n) for s,n in infantry],
           seconds=35,cost={'funds':120,'materials':25,'electronics':10,'fuel':5,'manpower':60})

supports = {
    'russia': [('kamaz5350_supply','KamAZ-5350 supply'),('brem1m_recovery','BREM-1M recovery'),('imr3m_engineer','IMR-3M engineer'),('mtu72_bridgelayer','MTU-72 bridgelayer'),('ur77_mineclearing','UR-77 mine clearing')],
    'ukraine': [('man_hx77_supply','MAN HX77 supply'),('buffel_recovery','Büffel recovery'),('kodiak_engineer','Kodiak engineer'),('leguan_bridgelayer','Leguan bridgelayer'),('trojan_breacher','Trojan breacher')]}
for country, rows in supports.items():
    prefix = 'russia' if country == 'russia' else 'euro'
    # Each support vehicle is separately producible, not a replacement for another role.
    for stem,name in rows:
        family(stem+'_'+country,country,name,'Support','support',
               [tier(prefix+'_'+stem,name if i==0 else name+' · L'+str(i+1)) for i in range(5)])

for country,prefix,rows in [
    ('russia','russia',[('2b14_mortar_82','2B14 82 mm mortar'),('2b11_mortar_120','2B11 120 mm mortar'),('d30_howitzer','D-30 howitzer')]),
    ('ukraine','euro',[('l16_mortar_81','L16 81 mm mortar'),('mo120rt_mortar','MO-120-RT mortar'),('l118_lightgun','L118 light gun')])]:
    for stem,name in rows:
        family(stem+'_'+country,country,name,'Artillery','artillery',[tier(prefix+'_'+stem,name if i==0 else name+' · L'+str(i+1)) for i in range(5)])
for country,prefix,rows in [
    ('russia','russia',[('il76md','Il-76MD transport'),('a50u','A-50U airborne radar'),('yak130','Yak-130')]),
    ('ukraine','euro',[('a400m_atlas','A400M Atlas transport'),('hawk_t2','Hawk T2')])]:
    for stem,name in rows:
        combat = stem in ['yak130','hawk_t2']
        family(stem+'_'+country,country,name,'Fighters' if combat else 'Support','fighter',
            [tier(prefix+'_'+stem,name if i==0 else name+' · L'+str(i+1)) for i in range(5)],
            role='fighter' if combat else 'transport',air_speed=2.5,air_range=16.0,requires_airbase=True,
            air_damage=2.0 if combat else 0.0,ground_damage=3.0 if combat else 0.0)
for country,stem,name in [('russia','russia_t14_armata','T-14 Armata'),('ukraine','euro_kf51_panther','KF51 Panther')]:
    family('advanced_tanks_'+country,country,name,'Armor','armor',[tier(stem,name if i==0 else name+' · L'+str(i+1)) for i in range(5)])

# Coastal launchers are ground units; missile bodies are flight assets, not ground vehicles.
for country,launcher,rows in [
    ('russia','russia_bastion_p_launcher',[('russia_p800_oniks','P-800 Oniks'),('russia_p800_oniks','Oniks · guidance'),('russia_3m22_zircon','3M22 Zircon'),('russia_3m22_zircon','Zircon · guidance'),('russia_3m22_zircon','Zircon · advanced')]),
    ('ukraine','euro_nsm_coastal_launcher',[('euro_nsm','NSM'),('euro_nsm','NSM · guidance'),('euro_nsm','NSM · sensors'),('euro_nsm','NSM · electronics'),('euro_nsm','NSM · advanced')])]:
    family('coastal_missiles_'+country,country,'Coastal missiles','Missiles','missile_launcher',
        [tier(launcher,name,projectile_model='res://assets/library/arsenal/'+body+'.glb') for body,name in rows],
        strike_range=8.0,strike_damage=22.0,reload_rounds=4.0,targets_naval=True)
# Ship and aircraft loadouts use their own supplied missile bodies.
for spec in catalog:
    for t in spec.get('research_tiers',[]):
        filename = Path(t.get('model','')).stem
        projectile = {'russia_buyan_m':'russia_kalibr_3m14','russia_admiral_gorshkov':'russia_3m22_zircon',
            'russia_kilo_sub':'russia_kalibr_3m14','russia_yasen_sub':'russia_p800_oniks',
            'russia_steregushchiy':'russia_p800_oniks','euro_type23':'euro_nsm','euro_type26':'euro_nsm',
            'euro_fremm':'euro_exocet_mm40','euro_horizon':'euro_rbs15_mk3','euro_efx_valour':'euro_nsm',
            'russia_su34':'russia_kh59mk2','russia_tu95ms':'russia_kh101','russia_tu160':'russia_kh101',
            'euro_rafale':'euro_storm_shadow','euro_tornado_ids':'euro_taurus_kepd350'}.get(filename)
        if projectile: t['projectile_model'] = 'res://assets/library/arsenal/'+projectile+'.glb'
        # Remove American models from the active playable roster as well.
        if filename == 'euro_m113': t.update(tier('euro_vab','VAB'))
        if filename in ['euro_m270','euro_m270_mlrs']: t.update(tier('euro_rm70_vampire','RM-70 Vampire · modernization'))
    if spec['visual_kind']=='naval':
        # Old PNGs depict the earlier meshes. Don't show a misleading ship portrait.
        for t in spec['research_tiers']: t.pop('preview',None)
        entry = next((x for x in roster if x['id']==spec['asset_roster_id']),None)
        if entry:
            for appearance in entry['assets'].values(): appearance.pop('preview',None)

# Include the supplied small arms and missile bodies in the existing model viewer.
showcase=[]
for name,path in sorted(found.items()):
    stem=path.stem
    showcase.append({'name':stem.replace('_',' ').title(),'kind':'Weapon' if stem.startswith('weapon_') else 'Equipment',
        'theme':'Russia' if stem.startswith('russia_') else 'Europe','model':'res://assets/library/arsenal/'+name})
for filename,value in [('equipment.json',catalog),('asset_roster.json',roster),('weapon_showcase.json',showcase)]:
    (data/filename).write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n')
manifest['source_files']=sorted(set(manifest['source_files']+['Weapons/'+p.name for p in incoming.glob('*.zip')]))
manifest['excluded_models']=sorted(excluded)
for name in list(manifest['models']):
    if Path(name).stem in excluded: del manifest['models'][name]
(root/'docs/ARSENAL_ASSETS.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Imported',len(found),'models;',len(catalog),'equipment families;',len(showcase),'viewer entries')
