"""Count actual per-tier natural homes over every address in a saved manifest.

This measures planet selection, not chance per minute or terrain placement. Uses
the documented SHA-256 streams from universe.gd; no meshes/worlds are instantiated.
"""
import json, math, hashlib, sys
from pathlib import Path
from collections import Counter
ROOT=Path(__file__).resolve().parents[1]

def derive(seed, stream):
    return int(hashlib.sha256(f'{seed}:{stream}'.encode()).hexdigest()[:8],16)&0x7fffffff

def measure(path):
    m=json.loads(Path(path).read_text());cfg=m['settings'];rules=cfg['ecology_rules']['native_biota'];seed=int(m['seed'])
    count=int(cfg['planet_count'])//int(cfg['planets_per_system']);bands=cfg['tier_weights'];per_band=count//len(bands)
    forms={}
    biota_source='biota_forms' if (ROOT/'우주-비즈니스/data/bestiary/biota_forms.json').exists() else 'biota_recipes'
    for name in ['forms','xenofauna_forms','xenoflora_forms',biota_source]:
        data=json.loads((ROOT/'우주-비즈니스/data/bestiary'/f'{name}.json').read_text())
        forms.update({r['id']:r for r in data.get('forms',data.get('species',[]))})
    solar_seed=derive(seed,m['id']+':system:0');rotation=derive(solar_seed,'angle')%1000000/1000000*math.tau
    sun_x=float(cfg['outer_radius'])+(float(cfg['inner_radius'])-float(cfg['outer_radius']))*(derive(solar_seed,'radius')%1000000/1000000)/len(bands)
    regions={r:{str(t):Counter() for t in range(1,6)} for r in ['galaxy','coreward_corridor','outside_corridor','outward_of_sun']}
    homes=m['native_biota']['planets'];owned_counts=Counter();total=0
    for index in range(count):
        system_seed=derive(seed,m['id']+f':system:{index}');band=min(index//per_band,len(bands)-1)
        fraction=derive(system_seed,'radius')%1000000/1000000
        radius=float(cfg['outer_radius'])+(float(cfg['inner_radius'])-float(cfg['outer_radius']))*(band+fraction)/len(bands)
        angle=derive(system_seed,'angle')%1000000/1000000*math.tau-rotation;x=math.cos(angle)*radius;y=math.sin(angle)*radius
        corridor=0<=x<=sun_x and abs(y)<=float(rules['corridor_width'])
        selected=['galaxy','coreward_corridor' if corridor else 'outside_corridor']
        if x>sun_x:selected.append('outward_of_sun')
        pair=index//2;s=cfg['system_rules'];first_count=8 if pair==0 else int(s['minimum_planets'])+derive(seed,f'system-pair-v1:{pair}')%(int(s['maximum_planets'])-int(s['minimum_planets'])+1)
        amount=first_count if index%2==0 else int(s['pair_planets'])-first_count
        first=pair*int(s['pair_planets'])+(0 if index%2==0 else first_count)
        for ordinal in range(first,first+amount):
            total+=1;id=m['id']+f':planet:{ordinal}';body_seed=derive(system_seed,id);roll=derive(body_seed,id+':tier')%100;tier=1
            for t,w in enumerate(bands[band],1):
                roll-=int(w)
                if roll<0:tier=t;break
            if index==0:tier=1
            home=homes.get(str(ordinal));presence=set();active=set()
            if home:
                assert tier==int(home['tier']),f'tier stream mismatch at {ordinal}'
                for row in home['lineages']:
                    category=forms[row['form_id']]['category'];presence.add(category)
                    if home['origin']=='established' or category!='animal':active.add(category)
                    owned_counts[category]+=1
            for region in selected:
                row=regions[region][str(tier)];row['planets']+=1
                if home:row['native_home']+=1
                if active:row['observable_home']+=1
                for c in presence:row[c+'_home']+=1
                for c in active:row[c+'_observable']+=1
    assert total==int(cfg['planet_count'])
    result={'seed':seed,'catalogue_hash':m['native_biota']['catalog_hash'],'catalogue_source':biota_source,'planet_count':total,'corridor_definition':f'0 <= x <= Sun.x, abs(y) <= {rules["corridor_width"]}, after rotating Sun east','meaning':'Natural home presence per uniformly selected planet of the same tier. Animals on dormant worlds are hidden until restoration; plant/microbial dormant colonies remain observable. Terrain reachability and time spent exploring are not included.','assigned_categories':dict(owned_counts),'regions':{}}
    for region,tiers in regions.items():
        result['regions'][region]={}
        for tier,row in tiers.items():
            values=dict(row)
            values['percent']={k:round(100*row[k]/max(1,row['planets']),4) for k in ['native_home','observable_home','animal_observable','plant_observable','microbe_observable']}
            result['regions'][region][tier]=values
    out=ROOT/'docs/production/media/biota/discovery-distribution.json';out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(result,ensure_ascii=False,indent=2))

if __name__=='__main__':measure(sys.argv[1])
