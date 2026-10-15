"""Add five-level cargo ship and oil tanker research using the owner's Drive originals.
Idempotent; also called after rebuilding the weapons catalogue.
"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def apply(catalog):
    for country in sorted({e['country'] for e in catalog if e.get('country')}):
        for family,name,stem,art in [('cargo','Cargo ships','container','civil_cargo_ship'),('tankers','Oil tankers','tanker','civil_oil_tanker')]:
            ident=f'{family}_{country}'
            if any(e['id']==ident for e in catalog): continue
            models=([f'civil_container_t1_feeder',f'civil_container_t2_panamax',f'civil_container_t3_ulcv'] if stem=='container' else ['civil_tanker_t1_coastal','civil_tanker_t2_aframax','civil_tanker_t3_vlcc'])
            tiers=[]
            for level,model in enumerate([models[0],models[0],models[1],models[1],models[2]],1):
                tiers.append({'name':f'{name} {level}','model':f'res://assets/library/transport/{model}.glb','preview':f'res://assets/interface/unit_art/{art}.webp','cargo_slots':30*level,'improvement':f'Capacity: {30*level} cargo slots ({3000*level:,} resource units). Same research artwork at every level.'})
            catalog.append({'id':ident,'country':country,'name':name,'category':'Navy','visual_kind':'naval','role':'freight','research_branch':name,'research_only':True,'starter':False,'seconds':60,'research_days':[1,4,8,12,16],'cost':{'funds':3000,'materials':900,'electronics':240,'fuel':300,'manpower':0,'food':0},'upkeep':{'funds':0,'fuel':0,'food':0,'manpower':0},'building_requirements':{'naval_base':1},'requires_port':True,'production_building':'naval_base','research_tiers':tiers,'model_status':'Original civilian_ships_train.zip from the owner’s Drive; research changes cargo capacity, not combat strength.'})
    return catalog
if __name__=='__main__':
    path=ROOT/'game/data/equipment.json'
    path.write_text(json.dumps(apply(json.loads(path.read_text())),indent=2,ensure_ascii=False)+'\n')
