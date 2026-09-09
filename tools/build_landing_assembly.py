"""Extend the editable Kestrel with hydraulic gear, an opening hatch and a sliding ramp."""
from pathlib import Path
import bpy, math, sys, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'));import ink_blender as ink
SRC=ROOT/'art/blender/ships';PRE=ROOT/'docs/production/media/landing-polish';PRE.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(SRC/'kestrel.blend'))
for o in list(bpy.context.scene.objects):
 if o.name.startswith(('Aft boarding','Hatch grip')):bpy.data.objects.remove(o,do_unlink=True)
cream=ink.material('enamel_cream');steel=ink.material('edge_steel');dark=ink.material('structural_dark');teal=ink.material('enamel_teal');orange=ink.material('safety_orange')
def pivot(n,p,parent=None):
 o=bpy.data.objects.new(n,None);bpy.context.collection.objects.link(o);o.location=p
 if parent:o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
 bpy.context.view_layer.update();return o
def attach(o,n,mat,parent=None):
 o.name=n;o.data.materials.append(mat);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);ink.manufactured_edges(o,.035,3)
 if parent:o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
 return o
def box(n,p,s,mat,parent=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s;return attach(o,n,mat,parent)
def rod(n,a,b,r,mat,parent=None):
 a,b=Vector(a),Vector(b);bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=r,depth=(b-a).length,location=(a+b)/2);o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return attach(o,n,mat,parent)
# Cut a real doorway through the aft pressure shell.
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,-6.7,-.05));cutter=bpy.context.object;cutter.scale=(1.88,2.0,1.9);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
hull=bpy.data.objects.get('Pressure hull');mod=hull.modifiers.new('Aft access opening','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter;bpy.context.view_layer.objects.active=hull;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
for x in [-1.08,1.08]:box('Access jamb',(x,-6.97,-.02),(.18,.25,2.15),steel)
box('Access lintel',(0,-6.97,1.07),(2.35,.25,.20),cream)
box('Airlock floor',(0,-6.25,-1.00),(2.0,1.6,.16),dark)
box('Airlock inner bulkhead',(0,-5.52,.0),(2.,.1,2.),dark)
for x in [-.92,.92]:box('Airlock lining',(x,-6.1,.0),(.09,1.5,2.),dark)
hatch=pivot('Anim_Hatch',(0,-7.04,-.03));box('Pressure hatch',(0,-7.04,-.03),(1.91,.12,1.91),teal,hatch)
for x in [-.52,.52]:box('Hatch handle',(x,-7.12,-.05),(.085,.08,.43),orange,hatch)
ramp=pivot('Anim_Ramp',(0,-7.08,-1.05));box('Ramp deck',(0,-9.08,-1.05),(2.0,4.0,.15),steel,ramp)
for y in [-7.3-i*.28 for i in range(14)]:box('Anti slip tread',(0,y,-.95),(1.75,.055,.04),dark,ramp)
for x in [-1.03,1.03]:
 box('Ramp edge rail',(x,-9.08,-.96),(.10,4.0,.25),orange,ramp)
 rod('Ramp hinge',(x-.10,-7.08,-1.05),(x+.10,-7.08,-1.05),.13,dark,ramp)
for side in [-1,1]:
 for y in [-4.9,1.2]:
  p=(side*1.4,y,-1.04);leg=pivot(f'Anim_LandingLeg_{side}_{y}',p)
  rod('Gear hinge',(side*1.1,y,-1.02),(side*1.7,y,-1.02),.18,dark,leg)
  rod('Hydraulic housing',p,(side*1.8,y,-1.95),.17,cream,leg)
  rod('Pressure line',(side*1.5,y+.22,-1.17),(side*1.9,y+.22,-2.02),.035,orange,leg)
  strut=pivot(f'Anim_Strut_{side}_{y}',(side*1.8,y,-1.85),leg)
  rod('Piston',(side*1.7,y,-1.65),(side*2.0,y,-2.4),.105,steel,strut)
  box('Landing foot',(side*2.0,y,-2.49),(1.08,1.28,.22),dark,strut)
  box('Foot pressure pad',(side*2.0,y,-2.36),(.68,.92,.09),steel,strut)
for side in [-1,1]:
 rod('Ventral thrust collar',(side*2.3,0,-.95),(side*2.3,0,-1.25),.38,steel)
 rod('Ventral thrust throat',(side*2.3,0,-1.24),(side*2.3,0,-1.28),.27,dark)
# Save editable geometry with deployed legs, closed hatch and extended ramp.
bpy.context.scene.unit_settings.system='METRIC'
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'kestrel_landing.blend'))
ink.consolidate_static_surfaces();bpy.ops.export_scene.gltf(filepath=str(ROOT/'우주-비즈니스/assets/models/ships/kestrel.glb'),export_format='GLB',export_cameras=False,export_lights=False)
# Display open doorway and sloping ramp for source inspection.
hatch.location.z+=1.95;ramp.rotation_euler.x=math.asin(1.5/4)
bpy.ops.mesh.primitive_plane_add(size=100,location=(0,0,-2.6));bpy.context.object.data.materials.append(dark)
bpy.ops.object.camera_add(location=(22,-29,15));cam=bpy.context.object;cam.rotation_euler=(Vector((0,-2,-.5))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=24;scene=bpy.context.scene;scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(2,-8,16));bpy.context.object.data.energy=2600;bpy.context.object.data.size=12;scene.world.color=(.22,.24,.27)
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1200;scene.render.resolution_y=900;scene.render.resolution_percentage=100;scene.render.filepath=str(PRE/'kestrel-landing-blender.png');bpy.ops.render.render(write_still=True)
(SRC/'landing-manifest.json').write_text(json.dumps({'source':'art/blender/ships/kestrel_landing.blend','previous_source_preserved':'art/blender/ships/kestrel.blend','model':'우주-비즈니스/assets/models/ships/kestrel.glb','generator':'tools/build_landing_assembly.py','articulation':['Anim_LandingLeg_*','Anim_Strut_*','Anim_Hatch','Anim_Ramp'],'status':'blender_rendered_pending_game_review'},indent=2)+'\n')
print('LANDING_ASSEMBLY_COMPLETE')
