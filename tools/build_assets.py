"""Create original industrial cartoon assets with Blender; retain editable sources.

Run: Blender --background --python tools/build_assets.py
All dimensions are metres. Blender Z-up is converted by glTF export to Godot Y-up.
"""
from pathlib import Path
import math
import random
import json
import sys
import bpy

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art" / "blender"
OUTPUT = ROOT / "우주-비즈니스" / "assets" / "models"
SOURCE.mkdir(parents=True, exist_ok=True)
OUTPUT.mkdir(parents=True, exist_ok=True)
random.seed(71491)

def material(name, rgb, metal=0.0, glow=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = 0.55
    if glow:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
        bsdf.inputs["Emission Strength"].default_value = glow
    return mat

def palette():
    return {
        "ink": material("Graphite / chassis", (0.035, 0.055, 0.075), 0.35),
        "edge": material("Edge steel", (0.24, 0.31, 0.34), 0.6),
        "cream": material("Ceramic enamel", (0.81, 0.83, 0.72), 0.15),
        "orange": material("Mine safety orange", (0.95, 0.36, 0.09), 0.15),
        "teal": material("Locus teal", (0.10, 0.46, 0.43), 0.2),
        "blue": material("Solar blue", (0.035, 0.12, 0.25), 0.3),
        "light": material("Status mint", (0.25, 0.95, 0.77), 0.1, 2.2),
        "violet": material("Ancient violet", (0.55, 0.25, 0.82), 0.25),
        "glass": material("Bio glass", (0.15, 0.62, 0.53), 0.5),
        "soil": material("Basalt", (0.25, 0.19, 0.23)),
        "leaf": material("Sage foliage", (0.22, 0.49, 0.28)),
    }

def finish(obj, name, mat, bevel=0):
    obj.name = name
    if mat: obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new("Enamel edge bevel", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj

def box(name, loc, size, mat, bevel=0.07):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bevel)

def cylinder(name, loc, radius, depth, mat, vertices=16, rotation=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    if rotation: obj.rotation_euler = rotation
    return finish(obj, name, mat, 0.025)

def sphere(name, loc, scale, mat, subdivisions=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat)

def label(text, loc, size, mat, rotation=(math.pi/2, 0, 0)):
    bpy.ops.object.text_add(location=loc, rotation=rotation)
    obj = bpy.context.object
    obj.data.body = text
    obj.data.size = size
    obj.data.extrude = 0.001
    obj.data.align_x = "CENTER"
    obj.data.materials.append(mat)
    bpy.ops.object.convert(target="MESH")
    return obj

def bolts(x_values, y, z, mat):
    for x in x_values:
        cylinder("Hex fastener", (x,y,z), 0.045, 0.035, mat, 6, (math.pi/2,0,0))

def base_plate(size, p):
    box("Foundation graphite", (0,0,0.13), (size,size,0.26), p["ink"])
    box("Inset apron", (0,0,0.29), (size-0.18,size-0.18,0.12), p["edge"], 0.025)
    for x in [-size/2+0.16,size/2-0.16]:
        for y in [-size/2+0.16,size/2-0.16]:
            cylinder("Foundation anchor", (x,y,0.34), 0.08, 0.05, p["orange"], 6)

def rover(p, version="miner"):
    color = p["orange"] if version == "miner" else (p["teal"] if version == "surveyor" else p["cream"])
    box("Suspension chassis", (0,0,0.57), (1.55,2.2,0.34), p["ink"])
    for x in [-0.88,0.88]:
        for y in [-0.74,0,0.74]:
            cylinder("Rubber tire", (x,y,0.46), 0.39, 0.30, p["ink"], 16, (0,math.pi/2,0))
            cylinder("Anim_Wheel_%s_%s" % (x,y), (x*1.19,y,0.46), 0.23, 0.04, color, 12, (0,math.pi/2,0))
            cylinder("Hub bolt", (x*1.23,y,0.46), 0.075, 0.06, p["edge"], 6, (0,math.pi/2,0))
    box("Armored body", (0,-0.12,1.05), (1.46,1.42,0.72), color, 0.13)
    box("Upper ceramic lid", (0,-0.12,1.44), (1.26,1.24,0.12), p["cream"])
    box("Dark front visor", (0,-0.846,1.18), (1.05,0.04,0.28), p["ink"], 0.045)
    for x in [-0.32,0.32]:
        box("Optical sensor", (x,-0.878,1.2), (0.16,0.04,0.115), p["light"], 0.02)
    bolts([-0.59,0.59], -0.851, 0.9, p["edge"])
    label("MINE" if version != "guardian" else "WARD", (0,-0.882,0.9), 0.18, p["cream"])
    for x in [-0.75,0.75]:
        box("Side bumper", (x,0,0.86), (0.1,1.6,0.14), p["edge"])
    box("Cargo bed", (0,0.89,0.98), (1.3,0.65,0.48), p["ink"])
    for x in [-0.48,0,0.48]:
        box("Cargo reinforcement", (x,0.93,1.22), (0.1,0.62,0.07), color, 0.01)
    cylinder("Antenna", (0.56,0.32,1.89), 0.027, 0.92, p["edge"], 8)
    sphere("Antenna LED", (0.56,0.32,2.36), (0.08,0.08,0.08), p["light"])
    cylinder("Tool mounting", (-0.43,-0.16,1.58), 0.20, 0.22, p["ink"])
    if version == "guardian":
        box("Anim_Turret", (0,0,1.76), (0.85,0.85,0.45), p["teal"])
        for x in [-0.22,0.22]:
            cylinder("Anim_Barrel_%s" % x, (x,-0.82,1.81), 0.08, 1.4, p["ink"], 12, (math.pi/2,0,0))
    else:
        arm = box("Mining arm", (-0.43,-0.88,1.66), (0.22,1.6,0.22), p["edge"])
        arm.rotation_euler.x = -0.22
        cylinder("Drill coupling", (-0.43,-1.63,1.45), 0.21, 0.32, color, 12, (math.pi/2,0,0))
        bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.27, radius2=0.025, depth=0.75, location=(-0.43,-2.12,1.35), rotation=(math.pi/2,0,0))
        finish(bpy.context.object, "ToolRotor", p["edge"])

def manual_tool(p):
    # Separate mechanical parts survive glTF consolidation for runtime animation.
    box("Insulated grip",(0,-0.18,-0.22),(0.22,0.30,0.46),p["ink"],0.045)
    box("Induction chassis",(0,0.06,0),(0.48,0.72,0.36),p["orange"],0.065)
    box("Ceramic upper shell",(0,0.02,0.20),(0.38,0.59,0.07),p["cream"],0.025)
    box("Status display",(0,-0.03,0.243),(0.23,0.19,0.022),p["ink"],0.012)
    for i in range(4): box("Charge bars",(-0.075+i*0.05,-0.02,0.258),(0.024,0.095,0.007),p["light"],0.003)
    cylinder("Vacuum chamber",(0,0.51,0),0.20,0.40,p["edge"],24,(math.pi/2,0,0))
    cylinder("Intake shadow",(0,0.753,0),0.205,0.018,p["ink"],24,(math.pi/2,0,0))
    for radius, y, color, name in [(0.218,0.69,"orange","Anim_Collar"),(0.227,0.76,"cream","Intake lip"),(0.17,0.775,"light","Induction halo")]:
        bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=(0,y,0),rotation=(math.pi/2,0,0),major_radius=radius,minor_radius=0.025)
        finish(bpy.context.object,name,p[color])
    fan_parts=[]
    for i in range(5):
        a=i*math.tau/5
        blade=box("Fan blade",(math.cos(a)*0.075,0.778,math.sin(a)*0.075),(0.16,0.018,0.028),p["teal"],0.007)
        blade.rotation_euler.y=-a
        fan_parts.append(blade)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in fan_parts: obj.select_set(True)
    bpy.context.view_layer.objects.active=fan_parts[0]
    bpy.ops.object.join()
    fan=bpy.context.object
    fan.name="Anim_Fan"
    bpy.context.scene.cursor.location=(0,0.778,0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    for x in [-0.27,0.27]:
        box("Intake guard",(x,0.35,0),(0.055,0.69,0.29),p["ink"],0.025)
        cylinder("Anim_Piston_%s" % x,(x,0.21,0.19),0.036,0.42,p["edge"],12,(math.pi/2,0,0))
        for i in range(5): box("Cooling vent",(x*0.91,-0.14+i*0.075,0.03),(0.024,0.025,0.15),p["cream"],0.005)
    cylinder("Core indicator",(0,0.79,0),0.045,0.019,p["light"],16,(math.pi/2,0,0))
    label("M-02",(0,-0.309,0.07),0.10,p["cream"])

def consolidate_export_meshes():
    """Keep editable parts in .blend, collapse static material groups in .glb."""
    groups={}
    for obj in list(bpy.context.scene.objects):
        if obj.type != "MESH" or (obj.name == "ToolRotor" or obj.name.startswith("Anim_")): continue
        bpy.context.view_layer.objects.active=obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        key=tuple(mat.name for mat in obj.data.materials)
        groups.setdefault(key,[]).append(obj)
    for group in groups.values():
        if len(group)<2: continue
        bpy.ops.object.select_all(action="DESELECT")
        for obj in group: obj.select_set(True)
        bpy.context.view_layer.objects.active=group[0]
        bpy.ops.object.join()

def building(kind, p):
    size = 3.6 if kind != "base" else 5.4
    base_plate(size, p)
    if kind == "charger":
        cylinder("Charging contact", (0,0,0.38), 1.05, 0.12, p["teal"], 32)
        for i in range(8):
            a = i*math.tau/8
            box("Charge marker", (math.cos(a)*1.27, math.sin(a)*1.27,0.4), (0.16,0.16,0.06), p["light"], 0.02)
        box("Charge terminal", (1.2,1.2,0.92), (0.34,0.34,1.16), p["cream"])
        return
    if kind == "solar":
        cylinder("Panel pedestal", (0,0,1.0), 0.15,1.5,p["edge"])
        panel=box("Panel frame",(0,0,1.8),(4.1,2.8,0.16),p["cream"])
        box("Dark cell substrate",(0,0,1.91),(3.99,2.7,0.06),p["ink"],0.02)
        for x in range(6):
            for y in range(4):
                box("Photovoltaic cell",(-1.66+x*0.665,-1.0+y*0.67,1.995),(0.62,0.62,0.075),p["blue"],0.012)
                box("Cell electrode",(-1.66+x*0.665,-1.0+y*0.67,2.04),(0.015,0.61,0.008),p["teal"],0)
        return
    if kind in ["base","factory","storage"]:
        height = 2.5 if kind == "base" else (2.8 if kind == "factory" else 1.55)
        width = 4.3 if kind == "base" else 2.8
        box("Machine shell",(0,0,height/2+0.34),(width,2.8,height),p["cream"],0.18)
        box("Roof trim",(0,0,height+0.36),(width+0.14,2.94,0.18),p["orange"] if kind=="factory" else p["teal"])
        box("Front panel",(0,-1.42,1.08),(width*0.78,0.08,1.1),p["ink"])
        if kind=="storage":
            for x in [-0.88,0,0.88]: box("Cargo door",(x,-1.49,1.12),(0.73,0.08,0.98),p["teal"])
        else:
            box("Access bay",(0,-1.5,0.94),(1.32,0.12,1.4),p["ink"])
            for x in [-0.75,0.75]: box("Door illumination",(x,-1.54,1.1),(0.05,0.05,1.45),p["light"],0)
        label({"base":"LOCUS / HOME","factory":"MINE / FAB-01","storage":"LOGISTICS"}[kind],(0,-1.477,height+0.05),0.24,p["ink"])
        for x in [-width/2+0.16,width/2-0.16]:
            for z in [0.66,height]: bolts([x],-1.49,z,p["edge"])
        for z in range(5): box("Vent grille",(width/2+0.03,0.1,1+z*0.17),(0.05,1.2,0.075),p["ink"],0.01)
        if kind=="base":
            cylinder("Comms mast",(1.6,0.7,3.9),0.08,2.2,p["edge"])
            sphere("Comms beacon",(1.6,0.7,5.1),(0.16,0.16,0.2),p["light"])
        return
    color = p["teal"] if kind in ["water","biolab"] else p["cream"]
    cylinder("Main pressure tank",(0,0,1.6),1.05,2.45,color,24)
    for z in [0.65,1.4,2.45]: cylinder("Tank reinforcement band",(0,0,z),1.13,0.14,p["ink"],24)
    cylinder("Top cap",(0,0,2.93),0.89,0.18,p["edge"],24)
    box("Service cabinet",(0,-1.2,1.1),(1.2,0.45,1.0),p["cream"])
    box("Readout",(0,-1.45,1.23),(0.78,0.03,0.38),p["ink"],0.02)
    for x in [-0.23,0,0.23]: box("Indicator",(x,-1.475,1.25),(0.09,0.02,0.18),p["light"],0.01)
    label({"atmosphere":"ATM / 01","thermal":"THERM / 02","water":"H2O / 03","biolab":"BIO / 04","reactor":"CORE / X"}[kind],(0,-1.443,0.81),0.17,p["ink"])
    if kind in ["atmosphere","thermal"]:
        for x in [-0.64,0.64]:
            cylinder("Exhaust chimney",(x,0,3.36),0.27,1.0,p["ink"],16)
            cylinder("Chimney cap",(x,0,3.88),0.34,0.13,p["orange"],16)
    elif kind == "water":
        for x in [-1.25,1.25]: cylinder("Auxiliary water tank",(x,0.4,1.35),0.36,1.9,p["teal"])
    elif kind == "biolab":
        sphere("Biodome",(0,0,3.0),(0.87,0.87,0.65),p["glass"],3)
        for i in range(5): sphere("Bio luminescence",(math.cos(i)*0.5,math.sin(i)*0.5,3.2),(0.12,0.12,0.18),p["light"])
    elif kind == "reactor":
        sphere("Ancient crystal core",(0,0,3.4),(0.55,0.55,1.0),p["violet"],1)
        for i in range(3):
            a=i*math.tau/3
            box("Containment prong",(math.cos(a)*0.7,math.sin(a)*0.7,3.55),(0.18,0.18,1.4),p["light"])

def environment(kind,p):
    if kind.startswith("ore_"):
        raise RuntimeError("Minerals are owned by tools/build_minerals.py")
    elif kind == "ruin":
        for x in [-1.2,1.2]:
            pillar=box("Ancient obelisk",(x,0,1.8),(0.85,0.85,3.6),p["soil"],0.15)
            pillar.rotation_euler.y=x*0.08
            for z in [1,1.6,2.2,2.8]: box("Ancient glyph",(x,-0.44,z),(0.28,0.025,0.08),p["light"],0.01)
        box("Lintel",(0,0,3.7),(3.6,1,0.6),p["soil"])
        sphere("Artifact core",(0,0,1.4),(0.48,0.48,0.85),p["violet"],1)
    elif kind == "microbe":
        cylinder("Microbial pool",(0,0,0.12),1.7,0.24,p["glass"],24)
        for i in range(9):
            a=i*2.4
            sphere("Colony vesicle",(math.cos(a),math.sin(a),0.35),(0.3,0.3,0.4),p["light"],1)
    elif kind == "animal":
        sphere("Mossling body",(0,0,0.8),(0.8,1.2,0.65),p["teal"],2)
        sphere("Mossling head",(0,-0.9,1.0),(0.62,0.6,0.55),p["cream"],2)
        for x in [-0.28,0.28]:
            sphere("Obsidian eye",(x,-1.41,1.17),(0.105,0.09,0.14),p["ink"],2)
            sphere("Eye glint",(x-0.02,-1.49,1.22),(0.026,0.022,0.035),p["light"],1)
            sphere("Ear",(x*1.9,-0.8,1.68),(0.18,0.2,0.55),p["teal"],1)
        for x in [-0.5,0.5]:
            for y in [-0.5,0.65]: sphere("Foot",(x,y,0.22),(0.22,0.28,0.25),p["ink"],1)
    elif kind == "civilization":
        for i in range(5):
            a=i*math.tau/5
            x,y=math.cos(a)*1.6,math.sin(a)*1.6
            cylinder("Settlement hut",(x,y,0.65),0.65,1.3,p["cream"],8)
            bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=0.85,depth=0.8,location=(x,y,1.55))
            finish(bpy.context.object,"Roof",p["teal"])
        cylinder("Signal spire",(0,0,1.8),0.13,3.6,p["violet"])
        sphere("Settlement beacon",(0,0,3.7),(0.24,0.24,0.4),p["light"],1)
    elif kind == "tree":
        cylinder("Trunk",(0,0,0.8),0.12,1.6,p["soil"],7)
        for z,radius in [(1.25,1.0),(1.95,0.78),(2.5,0.52)]:
            sphere("Foliage",(0,0,z),(radius,radius,0.75),p["leaf"],1)

records=[]
assets=["miner","surveyor","guardian","manual_tool","base","storage","solar","charger","factory","atmosphere","thermal","water","biolab","reactor",*["ore_"+x for x in ["iron","copper","stone","ice","crystal"]],"ruin","microbe","animal","civilization","tree"]
all_assets=assets.copy()
if "--" in sys.argv:
    requested=sys.argv[sys.argv.index("--")+1:]
    unknown=set(requested)-set(all_assets)
    if unknown: raise SystemExit("Unknown asset IDs: "+", ".join(sorted(unknown)))
    if requested: assets=[name for name in assets if name in requested]
for kind in assets:
    if kind.startswith("ore_"):
        print("MINERAL_PRESERVED",kind,"— rebuild with tools/build_minerals.py",flush=True)
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    p=palette()
    if kind == "manual_tool": manual_tool(p)
    elif kind in ["miner","surveyor","guardian"]: rover(p,kind)
    elif kind in ["base","storage","solar","charger","factory","atmosphere","thermal","water","biolab","reactor"]: building(kind,p)
    else: environment(kind,p)
    bpy.context.scene.unit_settings.system="METRIC"
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(kind+".blend")))
    editable_objects=len(bpy.context.scene.objects)
    consolidate_export_meshes()
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT/(kind+".glb")),export_format="GLB",export_apply=True,export_yup=True,export_cameras=False,export_lights=False)
    records.append({"id":kind,"source":str((SOURCE/(kind+".blend")).relative_to(ROOT)),"game":str((OUTPUT/(kind+".glb")).relative_to(ROOT)),"editable_objects":editable_objects,"export_objects":len(bpy.context.scene.objects),"generator":"tools/build_assets.py","blender":bpy.app.version_string})
    print("ASSET_COMPLETE",kind,flush=True)
manifest_path=SOURCE/"manifest.json"
previous=json.loads(manifest_path.read_text()) if manifest_path.exists() else []
merged={record["id"]:record for record in previous if record["id"] in all_assets}
merged.update({record["id"]:record for record in records})
manifest_path.write_text(json.dumps([merged[key] for key in all_assets if key in merged],ensure_ascii=False,indent=2)+"\n")
print("ASSET_BATCH_COMPLETE",len(records),"manifest total",len(merged),flush=True)
