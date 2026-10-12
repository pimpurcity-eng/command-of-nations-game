"""Install the owner's October 12 originals; retain all older models and save IDs."""
import copy, hashlib, json, shutil, sys
from pathlib import Path

root = Path(__file__).resolve().parents[1]
incoming = Path(sys.argv[1]).resolve()
assets = root / 'game/assets/library'
manifest = {'sources': [], 'files': {}}
for archive, destination in [
    ('navy_tiers_russia_europe', 'arsenal'),
    ('civilian_ships_train', 'transport'),
    ('buildings_part1_military_civic', 'buildings_oct12'),
    ('buildings_part2_walls_resources_rail_roads', 'buildings_oct12')]:
    manifest['sources'].append(archive + '.zip')
    for source in sorted((incoming / archive).rglob('*')):
        if not source.is_file() or source.suffix not in ['.glb', '.png']: continue
        target = assets / destination / source.name
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and target.read_bytes() != source.read_bytes():
            raise SystemExit('Refusing to replace a different original: ' + str(target))
        shutil.copyfile(source, target)
        manifest['files'][str(target.relative_to(root / 'game'))] = hashlib.sha256(source.read_bytes()).hexdigest()

data = root / 'game/data'
catalog = json.loads((data / 'equipment.json').read_text())
roster = json.loads((data / 'asset_roster.json').read_text())
showcase = json.loads((data / 'weapon_showcase.json').read_text())
def model(stem):
    path = assets / 'arsenal' / (stem + '.glb')
    assert path.exists(), stem
    return 'res://assets/library/arsenal/' + path.name
def naval(key, country, title, role, eras, template):
    old = next((s for s in catalog if s['id'] == key), None)
    spec = copy.deepcopy(old or next(s for s in catalog if s['id'] == template))
    spec.update(id=key, country=country, name=title, research_branch=title,
                asset_roster_id=key, role=role, production_building='naval_base')
    # Three supplied model eras, with explicit equipment upgrades between them.
    spec['research_tiers'] = []
    for era, upgraded in [(0,False),(0,True),(1,False),(1,True),(2,False)]:
        stem, name = eras[era]
        spec['research_tiers'].append({'name': name + (' · systems upgrade' if upgraded else ''),
            'model':model(stem), 'preview':model(stem)[:-4]+'_oct12_preview.png',
            'improvement':'Improved sensors and fire control' if upgraded else 'Original supplied model'})
    catalog[:] = [s for s in catalog if s['id'] != key] + [spec]
    appearance = {'model':spec['research_tiers'][0]['model'], 'original_colors':True,
                  'temporary_recolor':False, 'source_model':eras[0][1]}
    entry = {'id':key, 'name':title, 'kind':'naval', 'available_to':[country],
             'shared_building':False, 'assets':{'russian' if country=='russia' else 'european':appearance}}
    roster[:] = [s for s in roster if s['id'] != key] + [entry]

naval('fleet_russia','russia','Frigates','naval',[
 ('russia_frigate_t1_starting_krivak','Krivak'),('russia_frigate_t2_mid_admiral_grigorovich','Admiral Grigorovich'),('russia_admiral_gorshkov','Admiral Gorshkov')],'fleet_russia')
naval('fleet_ukraine','ukraine','Frigates','naval',[
 ('euro_type23','Type 23 Duke'),('euro_fremm','FREMM Aquitaine'),('euro_type26','Type 26 Glasgow')],'fleet_ukraine')
naval('destroyers_russia','russia','Destroyers','naval',[
 ('russia_destroyer_t1_starting_sovremenny','Sovremenny'),('russia_destroyer_t2_mid_slava','Slava'),('russia_destroyer_t3_modern_lider','Lider')],'fleet_russia')
naval('destroyers_ukraine','ukraine','Destroyers','naval',[
 ('euro_destroyer_t1_starting_type42','Type 42'),('euro_horizon','Horizon Andrea Doria'),('euro_destroyer_t3_modern_type45_daring','Type 45 Daring')],'fleet_ukraine')
naval('corvettes_russia','russia','Corvettes','naval',[
 ('russia_corvette_t1_starting_grisha','Grisha'),('russia_buyan_m','Buyan-M'),('russia_steregushchiy','Steregushchiy')],'fleet_russia')
naval('corvettes_ukraine','ukraine','Corvettes','naval',[
 ('euro_corvette_t1_starting_minerva','Minerva'),('euro_corvette_t2_mid_k130_braunschweig','K130 Braunschweig'),('euro_corvette_t3_modern_visby','Visby')],'fleet_ukraine')
naval('submarines_russia','russia','Submarines','submarine',[
 ('russia_kilo_sub','Kilo'),('russia_submarine_t2_mid_akula','Akula'),('russia_yasen_sub','Yasen')],'submarines_russia')
naval('submarines_ukraine','ukraine','Submarines','submarine',[
 ('euro_submarine_t1_starting_type209','Type 209'),('euro_submarine_t2_mid_type212a','Type 212A'),('euro_submarine_t3_modern_astute','Astute')],'submarines_russia')
naval('carriers_russia','russia','Aircraft carriers','carrier',[
 ('russia_carrier_t1_starting_kiev','Kiev'),('russia_admiral_kuznetsov','Admiral Kuznetsov'),('russia_carrier_t3_modern_shtorm','Shtorm')],'carriers_russia')
naval('carriers_ukraine','ukraine','Aircraft carriers','carrier',[
 ('euro_carrier_t1_starting_clemenceau','Clemenceau'),('euro_carrier_t2_mid_charles_de_gaulle','Charles de Gaulle'),('euro_hms_queen_elizabeth','Queen Elizabeth')],'carriers_ukraine')

buildings = json.loads((data / 'buildings.json').read_text())
mapping = {'factory':'ordnance_factory', 'industry':'industry', 'airbase':'aircraft_factory_l1',
 'recruitment_center':'recruitment_center', 'barracks':'barracks','tank_plant':'tank_plant',
 'naval_base':'naval_base', 'bunker':'city_walls_l1', 'infrastructure':'train_station'}
for definition in buildings:
    stem = mapping.get(definition['id'])
    if not stem: continue
    definition['model_tiers'] = ['res://assets/library/buildings_oct12/' +
        ('aircraft_factory_l'+str(i) if definition['id']=='airbase' else
         'city_walls_l'+str(i) if definition['id']=='bunker' else stem)+'.glb' for i in range(1,6)]
    definition['preview'] = 'res://assets/library/buildings_oct12/'+stem+'_menu.png'
    definition['original_colors'] = True
    entry = next(s for s in roster if s['id']==definition['asset_roster_id'])
    for appearance in entry['assets'].values():
        appearance.update(model=definition['model_tiers'][0],preview=definition['preview'],original_colors=True)
# Capital and resource originals are retained for map placement without inventing food economy.
for path in sorted((assets / 'transport').glob('*.glb')):
    uri = 'res://assets/library/transport/'+path.name
    if not any(s.get('model')==uri for s in showcase):
        showcase.append({'name':path.stem.replace('_',' ').title(),'kind':'Transport model',
                         'theme':'Civilian', 'model':uri})
for filename, value in [('equipment.json',catalog),('asset_roster.json',roster),
 ('buildings.json',buildings),('weapon_showcase.json',showcase)]:
    (data / filename).write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n')
(root/'docs/OCT12_ASSET_MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Installed',len(manifest['files']),'original files; naval families',sum(s['visual_kind']=='naval' for s in catalog))
