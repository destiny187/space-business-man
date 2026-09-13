"""Blender sources: articulated survey gloves and five ammunition packs (INK v1).
Run Blender --background --python tools/build_firearm_support.py -- [hands|ammo].
"""
from pathlib import Path
import sys, math, json
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as ink
import build_ink_industry as k
OUT=ROOT/'docs/production/media/firearm-upgrade';OUT.mkdir(parents=True,exist_ok=True)
SOURCE=ROOT/'art/blender/equipment';GAME=ROOT/'우주-비즈니스/assets/models'
mode=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
records=[]
def p(v):return Vector((v[0],-v[2],v[1]))
def box(name,at,size,role='dark',bevel=.02):
 return k.box(name,p(at),(size[0],size[2],size[1]),role,bevel)
def capsule(name,a,b,r,role='dark'):
 a,b=p(a),p(b)
 o=k.rod(name,a,b,r,role)
 for at in [a,b]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=r,location=at)
  end=bpy.context.object;end.name=name+' joint';end.data.materials.append(k.P[role]);
  for face in end.data.polygons:face.use_smooth=True
 return o

def render(name,target=(0,0,0),scale=2.0):
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
 scene.world=bpy.data.worlds.new('Firearm studio');scene.world.color=(.20,.20,.20)
 bpy.ops.object.camera_add(location=(1.45,1.8,1.1));cam=bpy.context.object
 cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=scale;scene.camera=cam
 for pos,energy in [((1,1,3),220),((-1,1,2),130)]:
  bpy.ops.object.light_add(type='AREA',location=pos);bpy.context.object.data.energy=energy;bpy.context.object.data.size=3
 scene.render.resolution_x=900;scene.render.resolution_y=720;scene.render.resolution_percentage=100
 scene.render.filepath=str(OUT/(name+'-blender.png'));bpy.ops.render.render(write_still=True)

def hands(side):
 k.reset();sign=1 if side=='right' else -1
 offset=Vector((0,0,0)) if sign==1 else Vector((0,.10,-.40))
 def pt(v):return Vector((v[0]*sign,v[1],v[2]))+offset
 bones=[];groups={}
 def addbone(name,a,b,parent=None):bones.append((name,p(pt(a)),p(pt(b)),parent))
 def attach(name,fn):
  before=set(bpy.context.scene.objects);fn();groups[name]=groups.get(name,[])+[o for o in set(bpy.context.scene.objects)-before if o.type=='MESH']
 addbone('upper_arm',(.34,-.20,1.40),(.40,-.58,1.0))
 addbone('forearm',(.40,-.58,1.0),(.13,-.35,.30),'upper_arm')
 attach('upper_arm',lambda:capsule('Upper pressure sleeve',pt((.34,-.20,1.40)),pt((.40,-.58,1.0)),.12,'teal'))
 attach('upper_arm',lambda:box('Shoulder ceramic shell',pt((.36,-.24,1.33)),(.23,.20,.25),'cream',.06))
 addbone('wrist',(.13,-.35,.30),(.11,-.23,.20),'forearm')
 attach('forearm',lambda:capsule('Pressure sleeve',pt((.42,-.63,1.05)),pt((.14,-.35,.31)),.105,'teal'))
 attach('forearm',lambda:box('Forearm ceramic guard',pt((.28,-.43,.60)),(.21,.13,.42),'cream',.045))
 attach('forearm',lambda:box('Recessed wrist display',pt((.19,-.31,.43)),(.13,.022,.12),'dark',.016))
 attach('forearm',lambda:box('Wrist status bar',pt((.19,-.294,.43)),(.075,.012,.018),'orange',.007))
 attach('wrist',lambda:capsule('Soft wrist seal',pt((.13,-.35,.30)),pt((.115,-.31,.25)),.080,'dark'))
 attach('wrist',lambda:box('Glove palm',pt((.11,-.245,.22)),(.12,.22,.105),'dark',.040))
 attach('wrist',lambda:box('Glove dorsal armor',pt((.175,-.235,.23)),(.027,.155,.086),'cream',.015))
 for i in range(4):
  y=-.175-i*.048
  chain=[(.12,y,.165),(.03,y-.007,.112),(-.039,y-.007,.139),(-.062,y,.207)]
  if i==0:chain=[(.11,-.15,.17),(.035,-.128,.11),(-.016,-.133,.105),(-.030,-.157,.135)]
  for n in range(3):
   name=f'finger_{i}_{n}';addbone(name,chain[n],chain[n+1],'wrist' if n==0 else f'finger_{i}_{n-1}')
   attach(name,lambda n=n,i=i:capsule(f'Finger {i} phalanx {n}',pt(chain[n]),pt(chain[n+1]),.022 if i else .021,'dark'))
   if n==0:attach(name,lambda y=y:box('Knuckle cap',pt((.106,y,.141)),(.04,.031,.025),'teal',.008))
 thumb=[(.135,-.16,.28),(.074,-.131,.272),(.01,-.145,.237)]
 for n in range(2):
  name=f'thumb_{n}';addbone(name,thumb[n],thumb[n+1],'wrist' if n==0 else 'thumb_0')
  attach(name,lambda n=n:capsule('Opposed thumb',pt(thumb[n]),pt(thumb[n+1]),.028,'dark'))
 # Bake bevels before binding, retaining smooth articulated finger surfaces.
 for group,objs in groups.items():
  for obj in objs:
   bpy.context.view_layer.objects.active=obj
   for mod in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
   vg=obj.vertex_groups.new(name=group);vg.add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
 bpy.ops.object.select_all(action='DESELECT')
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 for obj in meshes:obj.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();mesh=bpy.context.object;mesh.name='Survey glove and sleeve'
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 arm=bpy.data.armatures.new('Survey hand skeleton');rig=bpy.data.objects.new('SurveyHand',arm);bpy.context.collection.objects.link(rig)
 bpy.context.view_layer.objects.active=rig;mesh.select_set(False);rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 for name,a,b,parent in bones:
  bone=arm.edit_bones.new(name);bone.head=a;bone.tail=b
  if parent:bone.parent=arm.edit_bones[parent]
 bpy.ops.object.mode_set(mode='OBJECT');mesh.parent=rig;mod=mesh.modifiers.new('Glove skin','ARMATURE');mod.object=rig
 # Real skeleton clips; runtime blends wrist/finger poses with reload contact targets.
 for action_name,value in [('grip',0.0),('open',-.48),('trigger',.18)]:
  rig.animation_data_create();action=bpy.data.actions.new(action_name);rig.animation_data.action=action
  for name,a,b,parent in bones:
   bone=rig.pose.bones[name];bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0)
   if name.startswith('finger_') and (action_name=='open' or (action_name=='trigger' and name.startswith('finger_0'))):bone.rotation_euler.x=value
   for frame in [1,12]:bone.keyframe_insert('rotation_euler',frame=frame,group=name)
  track=rig.animation_data.nla_tracks.new();track.name=action_name;track.strips.new(action_name,1,action);track.mute=True
 rig.animation_data.action=None
 for bone in rig.pose.bones:bone.rotation_euler=(0,0,0)
 name='firearm_hand_'+side
 source=SOURCE/(name+'.blend');bpy.context.scene.unit_settings.system='METRIC';bpy.ops.wm.save_as_mainfile(filepath=str(source))
 bpy.ops.export_scene.gltf(filepath=str(GAME/'equipment'/(name+'.glb')),export_format='GLB',export_animations=True,export_animation_mode='ACTIONS',export_cameras=False,export_lights=False)
 records.append({'id':name,'source':str(source.relative_to(ROOT)),'model':'res://assets/models/equipment/'+name+'.glb','bones':len(bones),'clips':['grip','open','trigger'],'style':'INK v1'})
 render(name,p(pt((.1,-.25,.35))),1.55)

def ammo(name,recipe):
 k.reset()
 color_role='orange' if name=='ammo_shell' else 'teal'
 box('Ammunition tray',(0,.11,0),(.34,.19,.27),'dark',.025)
 box('Ceramic label panel',(0,.10,.145),(.27,.09,.025),'cream',.012)
 box('Latch',(.0,.02,.153),(.09,.025,.025),'orange',.009)
 for x in [-.13,.13]:box('Tray edge',(x,.22,0),(.04,.035,.27),'steel',.008)
 for x in ([-.075,.075] if name=="ammo_heavy" else [-.095,0,.095]):
  for z in [-.065,.065]:
   long=.24 if name in ['ammo_sniper','ammo_heavy'] else .16 if name!='ammo_plasma' else .20
   r=.041 if name=='ammo_heavy' else .026 if name!='ammo_shell' else .034
   if name in ['ammo_plasma','ammo_energy']:
    box('Sealed energy cell',(x,.22,z),(.055,.22,.085),'teal',.02)
    box('Cell terminals',(x,.34,z),(.043,.028,.052),'orange',.008)
   else:
    obj=k.cyl('Cartridge case',p((x,.19,z)),r,long,'steel',rot=(0,0,0))
    k.cyl('Primer rim',p((x,.19-long/2,z)),r*1.13,.016,'orange')
    if name=='ammo_shell':k.cyl('Crimped shell cap',p((x,.19+long/2,z)),r*.98,.016,'orange')
    else:
     bpy.ops.mesh.primitive_cone_add(vertices=32,radius1=r*.95,radius2=r*.17,depth=.07,location=p((x,.19+long/2+.025,z)))
     o=bpy.context.object;o.name='Projectile ogive';o.data.materials.append(k.P['cream']);ink.manufactured_edges(o,.003,3)
 source=SOURCE/(name+'.blend');bpy.context.scene.unit_settings.system='METRIC';bpy.ops.wm.save_as_mainfile(filepath=str(source));ink.consolidate_static_surfaces()
 (GAME/'products').mkdir(exist_ok=True)
 bpy.ops.export_scene.gltf(filepath=str(GAME/'products'/(name+'.glb')),export_format='GLB',export_cameras=False,export_lights=False)
 records.append({'id':name,'source':str(source.relative_to(ROOT)),'model':'res://assets/models/products/'+name+'.glb','style':'INK v1'})
 render(name,p((0,.15,0)),.75)
if not mode or 'hands' in mode:
 for side in ['right','left']:hands(side)
for name,recipe in json.loads((ROOT/'우주-비즈니스/data/firearms.json').read_text())['ammunition'].items():
 if not mode or 'ammo' in mode or name in mode:ammo(name,recipe)
manifest=SOURCE/'firearm-support.json'
previous=json.loads(manifest.read_text()) if manifest.exists() else []
ids={r['id'] for r in records};records=[r for r in previous if r['id'] not in ids]+records
manifest.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
pth=ROOT/'우주-비즈니스/data/render_assets.json';catalog=json.loads(pth.read_text());catalog=[r for r in catalog if r['id'] not in ids]
for r in records:
 if r['id'] not in ids:continue
 catalog.append({'id':r['id'],'title':'탄약·장갑','name':r['id'],'group':'장비','model':r['model'],'source':r['source'],'geometry':'firearm-support','foliage':False})
pth.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
