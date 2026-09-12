"""The 640 earlier animal identities still outside the large biota catalogue."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
CLASSIC={'lithic','grazer','runner','stalker','burrower','carapace','mantid','winged','swimmer','ray','coil','slug'}
ABERRANT={'blind_harp','spiral_maw','tripod_bell','lantern_sail','eye_orchard','asym_pincer','ribbon_colony','window_sac','crown_stalker','manymouth'}
XENO={'double_vault','walking_calyx','saddle_bridge','gyre_tower','twin_moons','accordion_shell','veil_antler','rib_sled','crown_anchor','inverted_fan','spiral_hinge','lattice_beast','funnel_stilt','crescent_maw','radial_mill','knuckle_chain','split_keel','petal_mantis','cup_colony','corkscrew_spine','umbrella_clutch','braid_crawler','offset_halo','root_octant'}
ORGANS=['armor','gills','mandibles','antennal_fans','siphons','sails','tendrils']
CLASSIC_TYPES={
    'lithic':['rhinocerid','armadillo','chelonian','proboscid','pangolin'],
    'grazer':['bovid','cervid','camelid','giraffoid','proboscid'],
    'runner':['macropod','lagomorph','anuran','giraffoid','gekkonid'],
    'stalker':['canid','felid','mustelid','skink','crocodilian'],
    'burrower':['mustelid','armadillo','monotreme','pangolin','skink'],
    'carapace':['crab','hermit','beetle','scorpion','crab'],
    'mantid':['mantid','scorpion','beetle','crab','hermit'],
}

def recipes():
    combat=json.loads((ROOT/'우주-비즈니스/data/wildlife_combat.json').read_text())
    ecology=json.loads((ROOT/'우주-비즈니스/data/ecology.json').read_text())
    rows=[]
    for file in ['forms','xenofauna_forms']:
        for f in json.loads((ROOT/f'우주-비즈니스/data/bestiary/{file}.json').read_text())['forms']:
            if f['category']!='animal' or f['family'] not in CLASSIC|ABERRANT|XENO:continue
            mode=int(f.get('anatomy',0));p=f.get('body_plan',{})
            # The older 25-species families repeated only five anatomy indices.
            # Give their five existing lineages distinct body/propulsion structures.
            lineage=(int(f['id'].rsplit('_',1)[1])-1)//5 if f['family'] in CLASSIC else 0
            morphology=dict(width=p.get('width',1+.035*(mode%5)+.08*lineage),height=p.get('height',1+.025*(mode//5)),mode=int(p.get('branch_mode',mode)),radial_count=p.get('radial_count',3+mode%5+lineage%3),limb_count=p.get('limb_count',4+2*(mode%3)),eye_count=f.get('eye_count',2),lineage=lineage)
            ground=f.get('locomotion_medium')=='ground' or f['family'] in ecology['ground_families']
            pattern=f.get('attack','none') if ground and f.get('attack') in combat['patterns'] else 'none'
            palette=f['palette'];rows.append(dict(id=f['id'],source_id=f['id'],name=f['name'],family=f['family'],kind=f['family'],construction=f['family'],anatomical_type=CLASSIC_TYPES.get(f['family'],[f['family']]*5)[lineage],organ_system=ORGANS[(mode+lineage)%7],environment=f['environment'],habitat=f.get('habitat_note',''),locomotion_medium=f.get('locomotion_medium','ground' if ground else ('water' if f['family'] in ['ray','swimmer','lantern_sail'] else 'air')),anatomy_note=f.get('anatomy_note','Original family rebuilt with articulated animal anatomy'),morphology=morphology,attack=f.get('attack','none'),palette=[palette[0],palette[1],'34494e',palette[2]],host_pattern=pattern,host_motion=combat['patterns'].get(pattern,{}).get('behavior',''),production_batch='r06',source_renderer='BLENDER_EEVEE'))
    assert len(rows)==640 and len({r['id'] for r in rows})==640
    return rows
