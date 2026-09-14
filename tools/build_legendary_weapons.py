"""Distinct legendary mechanisms on preserved Blender firearm originals; INK exports."""
from pathlib import Path
import sys, json, math
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as ink
import build_ink_industry as k
cfg=json.loads((ROOT/'우주-비즈니스/data/weapon_loot.json').read_text())
OUT=ROOT/'docs/production/media/weapon-loot';OUT.mkdir(parents=True,exist_ok=True)
records=[]
for name,spec in cfg['legendaries'].items():
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/equipment'/('gun_'+spec['family']+'.blend')))
 for short,role in {'cream':'enamel_cream','teal':'enamel_teal','orange':'safety_orange','dark':'structural_dark','steel':'edge_steel'}.items():k.P[short]=ink.material(role)
 if name=='ember':
  for side in [-1,1]:
   k.box('Enclosed heat exchanger',(side*.135,.19,.10),(.09,.38,.19),'dark',.025)
   for y in [.06,.13,.20,.27,.34]:k.box('Cooling fin',(side*.19,y,.12),(.05,.025,.24),'orange',.008)
 elif name=='shatter':
  for x in [-.13,.13]:
   k.cyl('Cryogenic pressure vessel',(x,.09,.28),.065,.34,'cream',(math.pi/2,0,0))
   k.pipe('Insulated coolant feed',[(x,.25,.28),(x,.38,.19),(x,.48,-.04)],.022,'teal')
 elif name=='arc':
  for x in [-.14,.14]:
   k.box('Capacitor guard',(x,.16,.16),(.09,.27,.17),'cream',.025)
   for y in [.07,.15,.23]:k.cyl('Induction coil',(x,y,.16),.07,.032,'orange',(math.pi/2,0,0))
 elif name=='pierce':
  for x in [-.105,.105]:
   k.box('Acceleration rail',(x,.53,.13),(.04,.58,.075),'teal',.012)
   for y in [.33,.48,.63,.78]:k.box('Rail bridge',(x,y,.13),(.075,.025,.095),'cream',.007)
 source=ROOT/'art/blender/equipment'/('legend_'+name+'.blend')
 bpy.ops.wm.save_as_mainfile(filepath=str(source))
 ink.consolidate_static_surfaces()
 dest=ROOT/'우주-비즈니스/assets/models'/ (spec['model']+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(dest),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
 scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Legendary inspection');scene.world.color=(.20,.20,.20)
 bpy.ops.object.camera_add(location=(1.4,1.7,1.2));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,.05))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.2;scene.camera=cam
 for pos,power in [((1,1,3),300),((-1,0,2),180)]:
  bpy.ops.object.light_add(type='AREA',location=pos);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.size=3
 scene.render.engine='CYCLES';scene.cycles.samples=12;scene.render.resolution_x=800;scene.render.resolution_y=600;scene.render.resolution_percentage=100
 scene.render.filepath=str(OUT/(name+'-blender.png'));bpy.ops.render.render(write_still=True)
 records.append({'id':'legend_'+name,'title':spec['name'],'name':spec['name'],'group':'장비','geometry':'ink-family-remodeled','foliage':False,'source':str(source.relative_to(ROOT)),'model':'res://assets/models/'+spec['model']+'.glb','generator':'tools/build_legendary_weapons.py','motion':['Anim_Bolt','Anim_Magazine'],'style':'INK v1'})
(ROOT/'art/blender/equipment/legendary_weapons.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
p=ROOT/'우주-비즈니스/data/render_assets.json';entries=json.loads(p.read_text());entries=[r for r in entries if r['id'] not in {a['id'] for a in records}];entries+=records;p.write_text(json.dumps(entries,ensure_ascii=False,indent=2)+'\n')
print('LEGENDARY_WEAPONS_EXPORTED',len(records))
