"""Original stratified mesa silhouettes. Editable Blender sources + single-mesh GLBs.
Run with Blender --background --python-exit-code 1 --python tools/build_landscape.py.
"""
from pathlib import Path
import bpy
import json
import math
import random

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/blender/landscape"
OUTPUT = ROOT / "우주-비즈니스/assets/models"
SOURCE.mkdir(parents=True, exist_ok=True)
records = []

def escarpment(name, center, radius, height, rng, mat):
    count = 18
    vertices, faces = [], []
    angular = [rng.uniform(.8, 1.2) for _ in range(count)]
    crown = [rng.uniform(-.06, .06) for _ in range(count)]
    # Overhanging strata and offset, broken crowns instead of rotational cones.
    tiers = [(0, 1.18), (.12, 1.04), (.24, .83), (.27, .89),
             (.52, .66), (.57, .74), (.83, .54), (.89, .60), (1, .35)]
    drift = (rng.uniform(-.28, .28), rng.uniform(-.24, .24))
    for layer, (z, width) in enumerate(tiers):
        for i in range(count):
            angle = i * math.tau/count
            r = radius * width * angular[i] * rng.uniform(.95, 1.05)
            vertices.append((center[0] + math.cos(angle)*r + drift[0]*radius*z,
                             center[1] + math.sin(angle)*r + drift[1]*radius*z,
                             max(0, z+crown[i]*z) * height))
            if layer:
                a = (layer-1)*count+i
                b = (layer-1)*count+(i+1)%count
                c = layer*count+(i+1)%count
                d = layer*count+i
                faces.extend([(a,b,c),(a,c,d)])
    faces.append(tuple(reversed(range(count))))
    faces.append(tuple((len(tiers)-1)*count+i for i in range(count)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj

for variant in range(3):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    rng = random.Random(18201+variant*713)
    mat = bpy.data.materials.new("Stratified basalt")
    mat.diffuse_color = (.31,.22,.20,1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = mat.diffuse_color
    bsdf.inputs["Roughness"].default_value = .93
    escarpment("Broken main crown", (0,0), 9, 22+variant*4, rng, mat)
    for i in range(3):
        angle = (i*2.1+variant*.7)
        escarpment("Eroded buttress %d" % i,
                   (math.cos(angle)*8,math.sin(angle)*8),
                   rng.uniform(3.8,5.5),rng.uniform(8,17),rng,mat)
    bpy.context.scene.unit_settings.system = "METRIC"
    key = "mesa_%d" % variant
    source = SOURCE / (key+".blend")
    output = OUTPUT / (key+".glb")
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = next(iter(bpy.context.scene.objects))
    bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=str(output),export_format="GLB",export_apply=True,
                             export_yup=True,export_cameras=False,export_lights=False)
    mesh = bpy.context.object.data
    mesh.calc_loop_triangles()
    records.append({"id":key,"source":str(source.relative_to(ROOT)),
                    "game":str(output.relative_to(ROOT)),"triangles":len(mesh.loop_triangles),
                    "editable_objects":4,"export_objects":1,"blender":bpy.app.version_string})
    print("LANDSCAPE_COMPLETE", key, len(mesh.loop_triangles), flush=True)
(SOURCE/"manifest.json").write_text(json.dumps(records,ensure_ascii=False,indent=2)+"\n")
