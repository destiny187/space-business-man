"""Type-specific Blender armatures and weighted tissue for the authored biota.
The 56 construction types select different axial, radial, laminar, paired or
branching skeletons. Existing authored appendage pivots become articulated bones.
Skinning and rigid shells are distinct; neither palettes nor random IDs choose rigs.
"""
import bpy, math
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree
from biota_midpoint import GROUND_KINDS

LAYOUTS={
 'spindle':'axial','lobopod':'metameric','radial':'radial','tower':'column','saddle':'vault',
 'mantle':'laminar','spiral':'helical','flat':'radial','chain':'metameric','bilateral':'paired','avian':'avian',
 'crown':'radial','amphora':'column','ribbon':'undulating','branch':'branching',
 'strap':'undulating','pitcher':'column','snap':'paired','sundew':'radial','bladder':'branching',
 'rafflesia':'radial','hydnora':'column','bromeliad':'radial','stilt':'branching','buttress':'column',
 'succulent':'column','caudex':'column','fern':'paired','horsetail':'column','fanpalm':'branching',
 'baobab':'branching','candelabra':'branching','spiralcone':'helical','floating_roots':'laminar',
 'basket':'vault','umbrella':'laminar','shield':'laminar','corkscrew':'helical','rattlepod':'branching',
 'orchid':'paired','lithops':'paired','stagfern':'branching','fenestrate':'laminar',
 'stromatolite':'radial','filament':'undulating','rosette':'radial','siphon':'branching',
 'vesicle':'radial','honeycomb':'laminar','diatom':'laminar','dendrite':'branching',
 'chimney':'column','fold':'undulating','lace':'vault','pustule':'paired','scroll':'helical','tubule':'radial',
}
# Deformation rates follow structural functions. Angular values are radians.
MOTIONS={
 'axial':(.85,.023,.016),'metameric':(1.1,.035,.022),'radial':(.7,.028,.012),
 'column':(.45,.018,.012),'vault':(.55,.024,.009),'laminar':(.65,.04,.016),
 'helical':(.6,.033,.013),'paired':(.7,.028,.012),'undulating':(1.0,.048,.025),'branching':(.5,.03,.011),'avian':(.8,.008,0.0),
}
for kind in GROUND_KINDS:
    LAYOUTS[kind]='serpentine' if kind=='serpent' else ('arthropod' if kind in ('arachnid','scorpion','crab','hermit','mantid','beetle') else ('saltatory' if kind in ('macropod','lagomorph','anuran') else 'tetrapod'))
MOTIONS.update(tetrapod=(.85,.009,0),saltatory=(.95,.009,0),arthropod=(.65,.008,0),serpentine=(1.05,.033,0))

def scaffold(row,low,high):
    layout=LAYOUTS[row['construction']];center=(low+high)*.5;span=high-low
    n=min(8,row['body_plan']['radial_count']);points=[];parents=[]
    def add(point,parent=-1):points.append(Vector(point));parents.append(parent)
    if row.get('anatomical_scaffold'):
        points=[Vector(p) for p in row['anatomical_scaffold']]
        parents=row.get('anatomical_scaffold_parents',[-1]+list(range(len(points)-1)))
        return layout,points,parents
    add((center.x,center.y,low.z+span.z*.26))
    if layout in ['axial','metameric','undulating']:
        for k in range(5):add((center.x+(.10*span.x*math.sin(k*1.4) if layout=='undulating' else 0),low.y+span.y*(.12+.19*k),center.z),0)
    elif layout=='avian':
        # Flight muscles and axial body tissue stay close to the torso, not the wing-tip bounds.
        points=[Vector((0,-.28,.70)),Vector((0,0,.83)),Vector((0,.35,.89)),Vector((0,.64,1.00))];parents=[-1,0,1,2]
    elif layout=='column':
        for k in range(4):add((center.x,center.y,low.z+span.z*(.3+k*.18)),max(0,k))
    elif layout in ['radial','laminar','branching']:
        for k in range(n):
            a=k*math.tau/n;z=center.z+(span.z*.15 if layout=='branching' else 0)
            add((center.x+math.cos(a)*span.x*.28,center.y+math.sin(a)*span.y*.28,z),0)
    elif layout in ['vault','paired']:
        for side in [-1,1]:
            for k in range(3):add((center.x+side*span.x*.20,low.y+span.y*(.20+k*.3),center.z+(.10*span.z*math.sin(k*math.pi/2) if layout=='vault' else 0)),0)
    elif layout=='helical':
        for k in range(6):
            a=k*math.tau/5;add((center.x+span.x*.20*math.cos(a),center.y+span.y*.20*math.sin(a),low.z+span.z*(.18+k*.13)),0)
    return layout,points,parents

def build(row,root):
    bpy.context.view_layer.update()
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    markers=[o for o in bpy.context.scene.objects if o.type=='EMPTY' and o!=root]
    bounds=[o.matrix_world@Vector(p) for o in objects for p in o.bound_box]
    low=Vector(tuple(min(p[i] for p in bounds) for i in range(3)));high=Vector(tuple(max(p[i] for p in bounds) for i in range(3)))
    layout,positions,parents=scaffold(row,low,high)
    arm=bpy.data.armatures.new('Anatomy_'+row['family']);rig=bpy.data.objects.new('BiotaSkeleton',arm);bpy.context.collection.objects.link(rig);rig.parent=root
    rig.show_in_front=True;arm.display_type='OCTAHEDRAL'
    bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
    main=arm.edit_bones.new('RigRoot');main.head=(0,0,0);main.tail=(0,.16,0)
    names=[]
    for k,position in enumerate(positions):
        bone=arm.edit_bones.new('Tissue_%02d'%k);bone.head=position;bone.tail=position+Vector((0,.14,0));bone.parent=main if parents[k]<0 else arm.edit_bones['Tissue_%02d'%parents[k]];names.append(bone.name)
    marker_names={o.name:'Rig_'+o.name for o in markers}
    for o in markers:
        bone=arm.edit_bones.new(marker_names[o.name]);bone.matrix=o.matrix_world.copy();bone.length=.16
    for o in markers:
        bone=arm.edit_bones[marker_names[o.name]]
        if o.parent and o.parent.name in marker_names:bone.parent=arm.edit_bones[marker_names[o.parent.name]]
        else:
            nearest=min(range(len(positions)),key=lambda k:(positions[k]-o.matrix_world.translation).length_squared)
            bone.parent=arm.edit_bones[names[nearest]]
    bpy.ops.object.mode_set(mode='OBJECT')
    tree=KDTree(len(positions))
    for k,p in enumerate(positions):tree.insert(p,k)
    tree.balance()
    weighted=0;rigid=0;weighted_vertices=0
    # Bone transforms retain authored hinge axes. Soft tissue binds to the nearest
    # two anatomical scaffold controls, while attached shells retain rigid weights.
    for ob in objects:
        parent=ob.parent;matrix=ob.matrix_world.copy()
        ob.data.transform(matrix);ob.parent=rig;ob.matrix_parent_inverse=Matrix.Identity(4);ob.matrix_basis=Matrix.Identity(4)
        if parent and parent.name in marker_names:
            group=ob.vertex_groups.new(name=marker_names[parent.name]);group.add(list(range(len(ob.data.vertices))),1.0,'REPLACE');rigid+=1
        else:
            groups=[ob.vertex_groups.new(name=name) for name in names]
            batches={}
            for vertex in ob.data.vertices:
                nearest=tree.find_n(vertex.co,2);inv=[1.0/max(.03,distance)**3 for _,_,distance in nearest];total=sum(inv)
                weights=[round(inv[0]/total*256),0];weights[1]=256-weights[0]
                for (_,k,_),weight in zip(nearest,weights):
                    if weight:batches.setdefault((k,weight),[]).append(vertex.index)
            for (k,weight),indices in batches.items():groups[k].add(indices,weight/256,'REPLACE')
            weighted+=1;weighted_vertices+=len(ob.data.vertices)
        modifier=ob.modifiers.new('Anatomical tissue skin','ARMATURE');modifier.object=rig;modifier.use_deform_preserve_volume=True
    speed,angle,translation=MOTIONS[layout]
    if row['category']=='microbe':speed*=.4;angle*=.5;translation*=.4
    elif row['category']=='plant':speed*=.65
    if row['locomotion_medium']=='atmosphere':speed*=.55;angle*=.7
    suffix=':'+row['anatomical_type'] if row.get('replacement') else (':avian' if layout=='avian' else '')
    row['rig']={'version':1,'template':row['family']+suffix,'construction':row['construction'],'layout':layout,'skeleton':'BiotaSkeleton','scaffold':names,'hinges':marker_names,'bone_count':len(arm.bones),'weighted_meshes':weighted,'weighted_vertices':weighted_vertices,'rigid_meshes':rigid,'motion':{'speed':speed,'angle':angle,'translation':translation},'skinned':True,'validation':'awaiting-type-motion-review'}
    rig['biological_construction']=row['construction'];rig['rig_template']=row['family']
    bpy.context.view_layer.update()
    return rig

def consolidate():
    """Join compatible skinned surfaces without applying away the armature."""
    groups={}
    for ob in list(bpy.context.scene.objects):
        if ob.type!='MESH':continue
        bpy.context.view_layer.objects.active=ob
        for modifier in list(ob.modifiers):
            if modifier.type!='ARMATURE':bpy.ops.object.modifier_apply(modifier=modifier.name)
        groups.setdefault((ob.parent,tuple(ob.data.materials)),[]).append(ob)
    for objects in groups.values():
        bpy.ops.object.select_all(action='DESELECT')
        for ob in objects:ob.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:bpy.ops.object.join()
    return len(groups)
