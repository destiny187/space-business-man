"""Space Y Mars environmental port and Earth freight endpoint. Blender sources + INK exports."""
from pathlib import Path
import bpy,math,json,sys,hashlib
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as ink
import corporate_marks as marks
SOURCE=ROOT/'art/blender/ships';OUT=ROOT/'우주-비즈니스/assets/models/ships'
CAP=ROOT/'docs/production/media/corporate-space';CAP.mkdir(parents=True,exist_ok=True)

def finish(o,name,role,bevel=0,parent=None):
    o.name=name;o.data.materials.append(ink.material(role));ink.manufactured_edges(o,bevel,4)
    if parent:o.parent=parent
    return o
def box(name,p,size,role='enamel_cream',parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(o,name,role,min(size)*.12,parent)
def cyl(name,p,r,d,role='edge_steel',parent=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=r,depth=d,location=p)
    return finish(bpy.context.object,name,role,min(r,d)*.08,parent)
def torus(name,p,r,t,role='edge_steel',parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=t,major_segments=96,minor_segments=12,location=p)
    return finish(bpy.context.object,name,role,0,parent)
def beam(name,a,b,r=2.0,role='edge_steel',parent=None):
    a,b=Vector(a),Vector(b);o=cyl(name,(a+b)*.5,r,(b-a).length,role,parent)
    o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def signal_material():
    mat=bpy.data.materials.new('Port guidance emission');mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.13,.55,.75,1)
    bs.inputs['Emission Color'].default_value=(.17,.75,1,1);bs.inputs['Emission Strength'].default_value=.65
    return mat
def light_bar(name,p,size):
    o=box(name,p,size,'structural_dark');o.data.materials.clear();o.data.materials.append(SIGNAL);return o
def freight_pod(p,accent='edge_steel'):
    x,y,z=p;box('Pressure freight module',p,(24,49,24))
    for yy in [-19,19]:box('Container locking collar',(x,y+yy,z),(26,3,26),accent)
    box('Recessed hatch',(x,y-25,z),(17,1.6,16),'structural_dark')
    for xx in [-8,8]:box('Hatch latches',(x+xx,y-26,z),(2,2,8),'safety_orange')
def dock(x,y,side):
    box('Open docking deck',(x,y,-27),(78,140,12),'structural_dark')
    box('Wear deck',(x,y,-19),(65,132,5),'edge_steel')
    for xx in [-34,34]:
        light_bar('Approach corridor',(x+xx,y,-14),(2,125,2))
        for yy in [-57,0,57]:box('Mooring clamp',(x+xx,y+yy,-10),(9,12,15),'safety_orange')
    for yy in [-45,-20,5,30]:box('Bay alignment marks',(x,y+yy,-15),(24,2,1),'enamel_cream')
    bpy.ops.object.empty_add(location=(x+side*48,y+22,-17));pivot=bpy.context.object;pivot.name='Anim_Crane_'+str(side)
    cyl('Crane base',(0,0,6),13,12,'edge_steel',pivot)
    beam('Service boom',(0,0,8),(0,0,57),7,'structural_dark',pivot)
    cyl('Gantry elbow',(0,0,57),10,12,'safety_orange',pivot)
    beam('Articulated transfer arm',(0,0,63),(-side*44,0,63),5,'enamel_cream',pivot)
    beam('Lifting wrist',(-side*44,0,63),(-side*44,0,38),3,'edge_steel',pivot)
    box('Idle magnetic head',(-side*44,0,34),(16,12,5),'safety_orange',pivot)
    bpy.ops.object.empty_add(location=(x,y,-8));bpy.context.object.name='Socket_Berth_'+str(side)
def panels(earth):
    for side in [-1,1]:
        y=side*(135 if earth else 118)
        beam('Array articulated boom',(0,side*75,-38),(0,y,-38),4)
        for x in [-56,56]:
            box('Solar frame',(x,y,-38),(95,61,4),'edge_steel')
            box('Photovoltaic slab',(x,y,-35),(90,56,2),'structural_dark')
            for i in range(-3,4):box('Cell divider',(x+i*12,y,-33),(1,56,1),'enamel_teal')
            for yy in [-16,0,16]:box('Busbar',(x,y+yy,-33),(90,.8,1),'edge_steel')
def port(earth):
    box('Load bearing spine',(0,0,-34),(44,225,26),'structural_dark')
    for side in [-1,1]:
        box('Pressure transfer bridge',(side*79,0,-24),(120,27,25))
        for yy in [-9,9]:beam('Bridge exposed conduits',(side*30,yy,-9),(side*129,yy,-9),2)
        dock(side*151,-38,side)
        for y in [41,94]:freight_pod((side*(42 if earth else 62),y,0))
    if earth:
        box('Freight control core',(0,-21,10),(62,121,52))
        box('Observation glass',(0,-83,20),(49,3,13),'structural_dark')
        for side in [-1,1]:
            box('Warehouse ridge',(side*30,-15,39),(9,110,6),'edge_steel')
            for y in [-58,-26,6,38]:box('Pressure bulkhead',(0,y,39),(49,4,6),'structural_dark')
    else:
        cyl('Environmental operations drum',(0,0,13),50,72,'structural_dark')
        for z in [-17,12,41]:
            torus('Pressure hull seam',(0,0,z),48,4)
            cyl('White radial casing',(0,0,z+6),49,17,'enamel_cream')
        cyl('Control panoramic windows',(0,0,59),39,12,'structural_dark')
        for i in range(12):
            a=i*math.tau/12;x,y=math.cos(a),math.sin(a)
            box('Window mullion',(x*39,y*39,59),(2,2,13),'edge_steel')
        cyl('Control crown',(0,0,68),42,7,'enamel_cream')
        # Maintenance vessels link the restored atmosphere to an industrial operator.
        for x in [-20,20]:
            cyl('Environmental reserve vessel',(x,86,15),12,69,'enamel_cream')
            for z in [-15,43]:torus('Reserve seam',(x,86,z),12,1.5)
    panels(earth)
    for x in [-13,13]:beam('Communications fork',(x,31,50),(x,31,101),2.5,'edge_steel')
    torus('Telemetry dish rim',(0,31,105),23,2.5,'enamel_cream')
    beam('Dish cross support',(-21,31,105),(21,31,105),1.5)
    beam('Dish cross support',(0,10,105),(0,52,105),1.5)
    light_bar('Telemetry beacon',(0,31,109),(5,5,7))
    marks.mount('Forward identity','space_y',(0,-85 if earth else -51,14),(1,0,0),(0,0,1),32)
    marks.mount('Deck identity','space_y',(0,-22,43 if earth else 74),(1,0,0),(0,1,0),34)

def export(id):
    scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.render.engine='CYCLES';scene.cycles.samples=20
    scene.world=bpy.data.worlds.new('Port studio');scene.world.color=(.055,.07,.085)
    bpy.ops.object.camera_add(location=(470,-610,410));cam=bpy.context.object
    cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=570;scene.camera=cam
    for loc,power,size in [((-250,-400,550),8000000,400),((350,-40,250),2500000,300),((0,370,400),7000000,250)]:
        bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    scene.render.resolution_x=1000;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.render.filepath=str(CAP/(id+'-blender.png'))
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(id+'.blend')))
    mesh_count=ink.consolidate_static_surfaces()
    geometry=[o for o in scene.objects if o.type in ['MESH','EMPTY']]
    bpy.ops.object.select_all(action='DESELECT')
    for o in geometry:o.select_set(True)
    path=OUT/(id+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_animations=False)
    record={'id':id,'source':str((SOURCE/(id+'.blend')).relative_to(ROOT)),'model':'res://assets/models/ships/'+id+'.glb','generator':'tools/build_orbital_ports.py','meshes':mesh_count,'triangles':sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in geometry if o.type=='MESH'),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'pivots':[o.name for o in geometry if o.type=='EMPTY']}
    bpy.ops.render.render(write_still=True)
    return record

records=[]
for id in ['solar_mars_port','solar_earth_logistics']:
    bpy.ops.wm.read_factory_settings(use_empty=True);SIGNAL=signal_material();port(id.endswith('logistics'));records.append(export(id))
(SOURCE/'orbital_ports.json').write_text(json.dumps(records,indent=2)+'\n')
