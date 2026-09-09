"""Additive Surveyor armor on the existing 13-bone rig; editable parts and dye channels."""
from pathlib import Path
import bpy, math, json, sys
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import ink_blender as ink
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/blender/crew/surveyor_augmented.blend'
OUTPUT=ROOT/'우주-비즈니스/assets/models/crew/surveyor_augmented.glb'
MEDIA=ROOT/'docs/production/media/suit-augmentation';MEDIA.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/crew/surveyor_suit.blend'))
rig=bpy.data.objects['SurveyorRig'];assert len(rig.data.bones)==13
base=[o for o in bpy.data.objects if o.type=='MESH']
parts={};groups={'Base':list(base)}
for obj in base:
 name=obj.name;bone=obj.vertex_groups[0].name
 part='helmet' if bone=='head' else 'belt' if bone=='pelvis' else 'arms' if 'arm' in bone else 'legs' if bone.startswith(('thigh','shin','foot')) else 'backpack' if name.startswith(('Life support','Air canister')) else 'chest'
 for slot in obj.material_slots:
  mat=slot.material
  channel={'cream':'primary','teal':'secondary','orange':'accent'}.get(mat.name)
  if channel:
   key='DYE::'+part+'::'+channel
   if key not in parts:parts[key]=mat.copy();parts[key].name=key
   slot.material=parts[key]
 obj['appearance_group']='Base';obj['dye_part']=part

def mat(part,channel):
 key='DYE::'+part+'::'+channel
 if key not in parts:
  parts[key]=ink.material({'primary':'enamel_cream','secondary':'enamel_teal','accent':'safety_orange'}[channel]).copy();parts[key].name=key
 return parts[key]
DARK=ink.material('structural_dark');STEEL=ink.material('edge_steel');RUBBER=ink.material('rubber')
lights={}
for branch,color in [('mobility',(.03,.38,.9)),('combat',(.8,.025,.035)),('vitality',(.02,.75,.25))]:
 m=bpy.data.materials.new('CORE::'+branch);m.diffuse_color=(*color,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Metallic'].default_value=.35;bs.inputs['Roughness'].default_value=.22;bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=.65;lights[branch]=m
current='';bone='';part=''
def finish(o,label,material,bevel=0):
 o.name=current+'__'+label
 o.data.materials.append(material)
 if bevel:ink.manufactured_edges(o,bevel,3)
 for mod in list(o.modifiers):bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 vg=o.vertex_groups.new(name=bone);vg.add(list(range(len(o.data.vertices))),1,'REPLACE')
 mod=o.modifiers.new('Surveyor deformation','ARMATURE');mod.object=rig;o.parent=rig
 o['appearance_group']=current;o['dye_part']=part;groups.setdefault(current,[]).append(o)
 return o

def loc(p):return (p[0],-p[2],p[1])
def box(label,p,s,m,b=.014):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc(p));o=bpy.context.object;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,label,m,b)
def plate(label,p,w,h,d,m):
 # Chamfered, tapered armor rather than a decorative rectangle.
 outline=[(-w*.34,-h*.5),(w*.34,-h*.5),(w*.5,-h*.27),(w*.43,h*.34),(w*.25,h*.5),(-w*.25,h*.5),(-w*.43,h*.34),(-w*.5,-h*.27)]
 verts=[loc((p[0]+x,p[1]+y,p[2]+z)) for z in [-d*.5,d*.5] for x,y in outline]
 faces=[tuple(range(7,-1,-1)),tuple(range(8,16))]+[(i,(i+1)%8,(i+1)%8+8,i+8) for i in range(8)]
 mesh=bpy.data.meshes.new(label);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(label,mesh);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;return finish(o,label,m,.008)
def cylinder(label,p,r,depth,m,axis=(0,1,0),vertices=20):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc(p));o=bpy.context.object
 v=Vector((axis[0],-axis[2],axis[1]));o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(v);bpy.ops.object.transform_apply(location=False,rotation=True,scale=True);return finish(o,label,m,.004)
def rod(label,a,b,r,m):
 a,b=Vector(a),Vector(b);return cylinder(label,(a+b)*.5,r,(b-a).length,m,b-a,12)
def stage(branch,tier,body_part):
 global current,part
 current='Aug_'+branch+'_'+str(tier);part=body_part

for side,x in [('L',-.18),('R',.18)]:
 sign=-1 if side=='L' else 1
 bone='shin_'+side;stage('mobility',1,'legs')
 plate('Shin outer shell '+side,(x,.29,-.15),.255,.245,.07,mat(part,'primary'))
 plate('Shin inset '+side,(x,.30,-.19),.085,.12,.018,mat(part,'secondary'))
 box('Shin marker '+side,(x,.32,-.204),(.027,.065,.01),lights['mobility'],.008)
 bone='foot_'+side;stage('mobility',2,'legs')
 plate('Toe guard '+side,(x,.16,-.295),.295,.12,.15,mat(part,'primary'))
 box('Heel cradle '+side,(x,.1,.115),(.3,.16,.11),mat(part,'secondary'))
 for dx in [-.115,.115]:box('Sole runner '+side,(x+dx,.055,-.12),(.052,.075,.46),RUBBER,.018)
 bone='shin_'+side;stage('mobility',3,'legs')
 rod('Piston sleeve '+side,(x+sign*.158,.21,.02),(x+sign*.158,.38,.02),.038,mat(part,'secondary'))
 rod('Piston ram '+side,(x+sign*.158,.13,.02),(x+sign*.158,.27,.02),.02,STEEL)
 for y in [.16,.39]:cylinder('Piston pivot '+side,(x+sign*.155,y,.02),.043,.043,DARK,(1,0,0))
 bone='thigh_'+side;stage('mobility',4,'legs')
 plate('Thigh exo rail '+side,(x,.665,-.155),.22,.255,.06,mat(part,'secondary'))
 plate('Thigh ceramic insert '+side,(x,.69,-.193),.125,.13,.02,mat(part,'primary'))
 bone='shin_'+side
 plate('Knee floating shield '+side,(x,.44,-.186),.25,.19,.045,mat(part,'primary'))
 box('Knee latch '+side,(x,.44,-.219),(.095,.052,.025),mat(part,'accent'))
 stage('mobility',5,'legs')
 plate('Calf power housing '+side,(x,.3,.18),.22,.23,.12,mat(part,'secondary'))
 for i in range(3):box('Calf cooling louver '+side,(x,.235+i*.055,.249),(.14,.018,.025),DARK,.005)
 cylinder('Calf blue core '+side,(x+sign*.157,.29,.15),.052,.032,lights['mobility'],(1,0,0),8)
 bone='foot_'+side
 box('Toe luminous rail '+side,(x,.19,-.378),(.13,.025,.012),lights['mobility'],.008)

for side,x in [('L',-.46),('R',.46)]:
 sign=-1 if side=='L' else 1
 bone='forearm_'+side;stage('combat',1,'arms')
 plate('Forearm face '+side,(x,.845,-.184),.245,.225,.058,mat(part,'primary'))
 plate('Forearm socket '+side,(x,.845,-.22),.12,.12,.018,mat(part,'secondary'))
 cylinder('Wrist ruby '+side,(x,.845,-.24),.034,.025,lights['combat'],(0,0,1),8)
 bone='upper_arm_'+side;stage('combat',2,'arms')
 plate('Pauldron front '+side,(sign*.41,1.35,-.153),.35,.23,.12,mat(part,'primary'))
 box('Shoulder crest '+side,(sign*.41,1.49,-.035),(.30,.075,.25),mat(part,'secondary'),.029)
 bone='forearm_'+side;stage('combat',3,'arms')
 rod('Forearm actuator '+side,(x+sign*.14,.72,.02),(x+sign*.14,.93,.02),.035,STEEL)
 box('Actuator shroud '+side,(x+sign*.14,.82,.01),(.088,.155,.13),mat(part,'secondary'),.027)
 for y in [.73,.92]:cylinder('Arm bearing '+side,(x+sign*.14,y,.01),.045,.04,DARK,(1,0,0))
 bone='upper_arm_'+side;stage('combat',4,'arms')
 plate('Upper arm shell '+side,(sign*.45,1.13,-.12),.24,.24,.09,mat(part,'primary'))
 box('Upper arm keeper '+side,(sign*.45,1.13,-.18),(.15,.055,.025),mat(part,'accent'))
 plate('Shoulder rear vane '+side,(sign*.43,1.35,.15),.35,.20,.10,mat(part,'secondary'))
 stage('combat',5,'arms')
 cylinder('Shoulder power rim '+side,(sign*.59,1.36,0),.102,.07,DARK,(1,0,0))
 cylinder('Shoulder power cover '+side,(sign*.63,1.36,0),.082,.025,mat(part,'primary'),(1,0,0),12)
 cylinder('Shoulder power core '+side,(sign*.648,1.36,0),.042,.015,lights['combat'],(1,0,0),8)
 bone='forearm_'+side
 for dx in [-.067,0,.067]:box('Knuckle armor '+side,(x+dx,.69,-.18),(.054,.075,.06),mat(part,'primary'),.02)

bone='spine';stage('vitality',1,'chest')
cylinder('Life core socket',(0,1.25,-.315),.115,.07,DARK,(0,0,1),8)
cylinder('Life core rim',(0,1.25,-.358),.094,.028,mat(part,'secondary'),(0,0,1),8)
cylinder('Life emerald',(0,1.25,-.38),.06,.027,lights['vitality'],(0,0,1),8)
stage('vitality',2,'chest')
for sign in [-1,1]:
 plate('Split breast guard',(sign*.205,1.24,-.256),.17,.365,.078,mat(part,'primary'))
 box('Chest clamp',(sign*.185,1.12,-.306),(.075,.055,.035),mat(part,'accent'))
stage('vitality',3,'backpack')
for sign in [-1,1]:
 cylinder('Reservoir belt',(sign*.22,1.17,.43),.145,.10,mat(part,'secondary'))
 box('Reserve housing',(sign*.22,1.16,.555),(.15,.32,.055),mat(part,'primary'),.025)
 box('Reserve status',(sign*.22,1.21,.59),(.035,.1,.014),lights['vitality'],.008)
box('Reservoir latch',(0,1.43,.415),(.075,.055,.03),mat(part,'accent'))
part='belt';bone='pelvis';box('Belt ceramic buckle',(0,.925,-.259),(.155,.065,.038),mat(part,'primary'))
bone='spine';part='chest';plate('Abdominal plate',(0,1.02,-.247),.34,.105,.06,mat(part,'secondary'))
stage('vitality',4,'chest')
for sign in [-1,1]:
 rod('Collar structural arch',(sign*.09,1.45,-.18),(sign*.275,1.4,-.16),.035,mat(part,'primary'))
 rod('Chest conduit',(sign*.13,1.16,-.294),(sign*.1,1.035,-.287),.017,STEEL)
 box('Collar emitter',(sign*.11,1.447,-.211),(.065,.025,.012),lights['vitality'],.007)
stage('vitality',5,'chest')
cylinder('Crown core gasket',(0,1.25,-.414),.123,.052,DARK,(0,0,1),8)
cylinder('Crown ceramic bezel',(0,1.25,-.447),.105,.025,mat(part,'primary'),(0,0,1),8)
cylinder('Crown emerald lens',(0,1.25,-.467),.072,.026,lights['vitality'],(0,0,1),8)
for sign in [-1,1]:
 plate('Chest exoskeleton wing',(sign*.315,1.255,-.16),.075,.28,.08,mat(part,'secondary'))
 box('Core gold restraint',(sign*.095,1.25,-.471),(.033,.068,.025),mat(part,'accent'),.009)
part='backpack';box('Back spinal power spine',(0,1.23,.46),(.13,.45,.12),mat(part,'secondary'),.025)
for y in [1.07,1.17,1.27,1.37]:box('Back thermal slot',(0,y,.528),(.079,.027,.025),DARK,.006)

part='helmet';bone='head';box('Helmet accent ridge',(0,1.98,.005),(.045,.012,.14),mat(part,'accent'),.004)

# Preserve the editable original parts/weights; consolidate only the export copy by appearance layer.
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
for name,objects in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0]
 if len(objects)>1:bpy.ops.object.join()
 bpy.context.object.name=name
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(OUTPUT),export_format='GLB',export_yup=True,export_animations=False)
meshes=[o for o in bpy.data.objects if o.type=='MESH']
for o in meshes:o.data.calc_loop_triangles()
manifest={'source':str(SOURCE.relative_to(ROOT)),'output':str(OUTPUT.relative_to(ROOT)),'bones':len(rig.data.bones),'meshes':len(meshes),'triangles':sum(len(o.data.loop_triangles) for o in meshes),'surfaces':sum(len(o.data.materials) for o in meshes),'layers':list(groups),'dye_slots':list(parts),'thresholds':json.loads((ROOT/'우주-비즈니스/data/suit_appearance.json').read_text())['thresholds']}
(ROOT/'art/blender/crew/surveyor_augmentation.json').write_text(json.dumps(manifest,indent=2))
print('AUGMENTED_SUIT',json.dumps(manifest))
# Blender source render (read source again to verify the delivered editable file).
bpy.ops.wm.open_mainfile(filepath=str(SOURCE));rig=bpy.data.objects['SurveyorRig']
for name,angle in {'thigh_L':.32,'shin_L':-.55,'foot_L':.23,'forearm_L':.35,'forearm_R':.22}.items():
 b=rig.pose.bones[name];b.rotation_mode='XYZ';b.rotation_euler.x=angle
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.02));floor=bpy.context.object;floor.data.materials.append(ink.material('structural_dark'))
bpy.ops.object.camera_add(location=(3.3,5.5,2.7));camera=bpy.context.object;camera.rotation_euler=(Vector((0,0,1))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=2.6
scene=bpy.context.scene;scene.camera=camera;scene.render.engine='CYCLES';scene.cycles.samples=16
for p,power,size in [((2,3,5),600,4),((-3,2,3),320,3),((1,-3,4),750,3)]:
 bpy.ops.object.light_add(type='AREA',location=p);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
scene.world.color=(.2,.2,.2);scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.filepath=str(MEDIA/'blender-rig.png');bpy.ops.render.render(write_still=True)
