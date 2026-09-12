"""One working T3 memory archive: removable records, hinged power bay, memory rotor."""
from pathlib import Path
import sys, json, math
import bpy
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_ink_industry as kit
import ink_blender as ink
SOURCE=ROOT/'art/blender/discoveries/lost_technology_archive.blend'
GAME=ROOT/'우주-비즈니스/assets/models/discoveries/lost_technology_archive.glb'
REVIEW=ROOT/'docs/production/media/t3-progression'
REVIEW.mkdir(parents=True,exist_ok=True)
kit.reset()
# Ancient materials retain their own palette; only the improvised replacement uses
# present-day INK industrial enamel. Wear is modeled, not painted onto a new cabinet.
for role,color in {'old':(.20,.22,.19),'oxide':(.20,.075,.026),'dust':(.20,.15,.095),'tablet':(.40,.34,.23),'patina':(.065,.14,.13),'char':(.032,.029,.027)}.items():
 mat=bpy.data.materials.new('Archive '+role);mat.diffuse_color=(*color,1);mat.use_nodes=True
 bsdf=mat.node_tree.nodes['Principled BSDF'];bsdf.inputs['Base Color'].default_value=mat.diffuse_color;bsdf.inputs['Roughness'].default_value=.88
 kit.P[role]=mat

def shard(name,outline,z,thickness,role,parent=None):
 n=len(outline);vertices=[(x,y,z+h) for h in [0,thickness] for x,y in outline]
 faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);bpy.context.view_layer.objects.active=obj;obj.select_set(True)
 kit.finish(obj,name,role,.014,parent);obj.select_set(False);return obj

shard('Fractured sunken plinth',[(-2.25,-1.6),(.5,-1.56),(.75,-1.38),(1.2,-1.54),(2.25,-1.32),(2.1,1.5),(.15,1.58),(-.18,1.32),(-2.3,1.4)],-.12,.36,'char')
for i,(x,y,sx,sy,angle) in enumerate([(-1.2,-.5,1.9,1.8,-.06),(1.1,.6,1.65,1.6,.13),(.85,-.8,1.7,.8,-.12)]):
 panel=kit.box('Separated buried floor '+str(i),(x,y,.22),(sx,sy,.13),'old',.025);panel.rotation_euler.z=angle
kit.pipe('Exposed severed floor conductor',[(-2,-.2,.29),(-.9,-.05,.31),(-.45,-.4,.30)],.03,'oxide')
# Missing front quadrant makes the corroded internal stack visible.
for n in range(9):
 a=math.radians(5+n*30);b=a+math.radians(25);r=.88
 height=1.45 if n not in [5,8] else 1.16
 verts=[]
 for z in [.35,height+ .35]:
  for radius in [r-.10,r]:
   for angle in [a,b]:verts.append((math.cos(angle)*radius,.25+math.sin(angle)*radius,z))
 mesh=bpy.data.meshes.new('Broken shell');mesh.from_pydata(verts,[],[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]);mesh.update()
 obj=bpy.data.objects.new('Chipped ceramic sector',mesh);bpy.context.collection.objects.link(obj);bpy.context.view_layer.objects.active=obj;obj.select_set(True);kit.finish(obj,obj.name,'patina' if n%3 else 'old',.022);obj.select_set(False)
kit.cyl('Oxidized core bearing',(0,.25,.48),.72,.3,'oxide')
for z in [.70,.98,1.26,1.54]:
 kit.cyl('Layered memory wafer',(0,.25,z),.59,.13,'char')
 kit.ring('Tarnished memory track',(0,.25,z+.06),.47,.025,'tablet')
for x,y,z in [(-.7,.22,2.2),(.55,.6,1.95)]:
 kit.rod('Bent exposed support',(x,y,.35),(x+.10,y+.08,z),.055,'oxide')
rotor=kit.pivot('Anim_Rotor_Memory',(0,.25,1.94))
kit.cyl('Damaged index wheel',(0,.25,1.94),.49,.12,'old',parent=rotor)
for a in [0,1,3,4]:
 angle=a*math.pi/3
 piece=kit.box('Missing-tooth index segment',(math.cos(angle)*.54,.25+math.sin(angle)*.54,1.98),(.27,.2,.10),'oxide',.012,rotor);piece.rotation_euler.z=angle
# A stack of actual engraved records behind a broken lid.
kit.box('Record rack remains',(-1.5,.08,.68),(1.0,1.55,.76),'char',.035)
for i in range(4):
 tablet=shard('Chipped record plate '+str(i),[(-1.99,-.72),(-1.22,-.72),(-1.03,-.49),(-1.09,.70),(-1.36,.81),(-2.0,.62)],.85+i*.075,.045,'tablet')
 tablet.rotation_euler.z=-.055+i*.032
# Large etched diagram on the exposed top record: thick routes and broken rings.
for start,end in [((-1.85,-.48,1.14),(-1.26,-.48,1.14)),((-1.85,-.25,1.14),(-1.52,-.25,1.14)),((-1.52,-.25,1.14),(-1.52,.45,1.14)),((-1.8,.23,1.14),(-1.27,.23,1.14))]:kit.rod('Engraved record line',start,end,.012,'char')
for x,y in [(-1.8,-.25),(-1.52,.45),(-1.27,.23)]:kit.ring('Record node',(x,y,1.15),.06,.012,'char')
cover=kit.pivot('Anim_Cover_Records',(-1.5,.73,1.19))
shard('Broken openable archive cover',[(-2,-.67),(-1.65,-.7),(-1.59,-.29),(-1.33,-.13),(-1.0,.18),(-1.01,.75),(-2.02,.73)],1.18,.08,'patina',cover)
kit.rod('Crooked hinge pin',(-2.04,.75,1.22),(-1.01,.75,1.18),.044,'oxide',cover)
# The right-hand unit has no enclosure: mismatched braces, torn wiring, replacement circuit.
for x in [1.14,1.91]:kit.rod('Exposed power frame',(x,.7,.25),(x-.13,.64,1.67),.053,'oxide')
kit.rod('Temporary diagonal brace',(1.16,-.4,.35),(1.82,.65,1.57),.06,'old')
for z in [.58,.95,1.34]:kit.box('Burnt backplane',(1.47,.57,z),(.76,.14,.23),'char',.012)
kit.pipe('Loose cable end',[(1.73,.47,1.46),(1.95,.0,1.20),(1.92,-.37,.54),(1.64,-.57,.35)],.035,'oxide')
kit.pipe('Dangling insulation',[(1.25,.4,1.4),(1.08,.2,1.1),(1.19,-.04,.65)],.048,'char')
power=kit.pivot('Anim_Power_Cassette',(1.55,-.65,.86))
kit.box('Improvised new control board',(1.55,-.65,.86),(.57,.19,.46),'teal',.025,power)
kit.box('Replacement circuit strap',(1.55,-.77,.87),(.66,.08,.075),'steel',.016,power)
glow=kit.pivot('Anim_Glow_Power',(1.39,-.8,.98))
kit.cyl('Only surviving status lamp',(1.39,-.8,.98),.045,.035,'status',(math.pi/2,0,0),glow)
kit.pipe('Patched bypass',[(1.55,.55,1.54),(1.1,.81,1.65),(.58,.75,1.36)],.045,'oxide')
# Fallen outer panel and broad windblown dirt islands break the new-appliance silhouette.
fallen=kit.box('Detached armor sheet',(1.62,-1.00,.38),(1.12,.62,.065),'patina',.02);fallen.rotation_euler=(.2,.15,-.25)
for i,(x,y,size) in enumerate([(-2.1,-1.15,.33),(-1.9,1.0,.30),(.93,-1.28,.36),(1.95,1.08,.28),(-.1,-.74,.17)]):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,y,.24));obj=bpy.context.object;obj.scale=(size,size*.7,.12);kit.finish(obj,'Sediment and broken fragments','dust',0)
kit.box('Cracked reader pedestal',(0,-.97,.57),(.86,.51,.42),'char',.025)
# A broken document is the focal point, propped up on a dead reader.
record=kit.pivot('Propped surviving record',(0,-1.0,.81))
shard('Readable fractured record',[(-.49,-1.39),(.14,-1.39),(.22,-1.26),(.44,-1.30),(.49,-.72),(.23,-.60),(-.48,-.65)],.83,.045,'tablet',record)
for start,end in [((-.35,-1.25,.887),(.05,-1.25,.887)),((-.35,-1.10,.887),(-.13,-1.10,.887)),((-.13,-1.10,.887),(-.13,-.76,.887)),((-.32,-.88,.887),(.31,-.88,.887)),((.13,-.88,.887),(.13,-1.07,.887))]:
 kit.rod('Surviving etched diagram',start,end,.018,'char',record)
for x,y in [(-.13,-.76),(.31,-.88),(.13,-1.07)]:kit.ring('Large etched junction',(x,y,.887),.055,.014,'char',parent=record)
fracture=[(-.43,-.66,.89),(-.22,-.78,.89),(-.28,-.99,.89),(-.18,-1.15,.89)]
for i in range(len(fracture)-1):kit.rod('Record fracture',fracture[i],fracture[i+1],.015,'oxide',record)
record.rotation_euler.x=math.radians(48)
# Broad irregular oxidation survives the game's three-value cartoon lighting.
for n in [0,3,6,7,8]:
 a=math.radians(5+n*30); width=math.radians(25)
 uv=[(.02,.04),(.96,.04),(.87,.24),(.54,.17),(.43,.40),(.18,.31),(.05,.62)]
 vertices=[(math.cos(a+u*width)*.889,.25+math.sin(a+u*width)*.889,.36+v*1.18) for u,v in uv]
 mesh=bpy.data.meshes.new('Irregular exposed oxidation');mesh.from_pydata(vertices,[],[tuple(range(len(vertices)))]);mesh.update();obj=bpy.data.objects.new('Peeling shell and rust',mesh);bpy.context.collection.objects.link(obj);obj.data.materials.append(kit.P['oxide'])
shard('Flaked floor enamel',[(-2,-1.23),(-1.32,-1.23),(-1.44,-1.11),(-1.71,-1.15),(-1.82,-.99),(-2.02,-1.09)],.298,.014,'oxide')
bpy.context.scene.unit_settings.system='METRIC';bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
ink.consolidate_static_surfaces()
bpy.ops.export_scene.gltf(filepath=str(GAME),export_format='GLB',export_cameras=False,export_lights=False)
kit.REVIEW=REVIEW;kit.render('lost-archive')
(SOURCE.with_suffix('.json')).write_text(json.dumps({'source':str(SOURCE.relative_to(ROOT)),'model':str(GAME.relative_to(ROOT)),'generator':'tools/build_lost_archive.py','blender':bpy.app.version_string,'forward':'Godot +Z','motions':['Anim_Cover_Records','Anim_Power_Cassette','Anim_Rotor_Memory'],'state':'weathered broken archive with engraved records and improvised power repair'},ensure_ascii=False,indent=2)+'\n')
