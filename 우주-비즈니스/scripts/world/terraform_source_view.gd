class_name FrontierTerraformSourceView
extends Node3D
## A bounded environmental source, separate from exploration discoveries and rewards.
var terrain: FrontierTerrainStreamer
var body: Dictionary
var site: Dictionary={}
var marker: Node3D
var plume: GPUParticles3D
var label: Label3D
var pool: MeshInstance3D
var material: StandardMaterial3D
var cache: Dictionary={}
func configure(stream: FrontierTerrainStreamer,planet: Dictionary) -> void:terrain=stream;body=planet
func accept(ledger: Dictionary) -> void:
 site=ledger.get("sites",{}).get(body.id,{})
 if not site.has("tier3"):return
 if marker==null:
  marker=Node3D.new();add_child(marker)
  var center:=FrontierCrewWorld.vector(site.regions["region:1"].center);center.y=terrain.field.height(center.x,center.z);marker.position=center
  for n in 3:
   var rock: Node3D=load("res://assets/models/ore_stone_b.glb").instantiate();FrontierInkStyle.apply(rock,cache);marker.add_child(rock)
   var a:=n*TAU/3;rock.position=Vector3(cos(a)*1.5,0,sin(a)*1.5);rock.rotation.y=a;rock.scale=Vector3(1.8,1.3,1.8)
  pool=MeshInstance3D.new();var disc:=CylinderMesh.new();disc.top_radius=2;disc.bottom_radius=2;disc.height=.07;pool.mesh=disc;pool.position.y=.05;marker.add_child(pool)
  material=StandardMaterial3D.new();material.roughness=.5;pool.material_override=material
  plume=GPUParticles3D.new();plume.amount=24;plume.lifetime=4;plume.visibility_aabb=AABB(Vector3(-8,-2,-8),Vector3(16,18,16));marker.add_child(plume)
  var process:=ParticleProcessMaterial.new();process.direction=Vector3.UP;process.spread=24;process.initial_velocity_min=1;process.initial_velocity_max=2;process.gravity=Vector3(0,.2,0);process.scale_min=.3;process.scale_max=1.1;process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE;process.emission_sphere_radius=.8;plume.process_material=process
  var quad:=QuadMesh.new();quad.size=Vector2(.8,.8);var smoke:=StandardMaterial3D.new();smoke.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;smoke.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;smoke.vertex_color_use_as_albedo=true;smoke.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;smoke.albedo_color=Color(1,1,1,.28);quad.material=smoke;plume.draw_pass_1=quad
  label=Label3D.new();label.font=load("res://assets/fonts/NotoSansKR.ttf");label.font_size=40;label.pixel_size=.008;label.position=Vector3(0,4,0);label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.outline_size=8;marker.add_child(label)
 var record: Dictionary=site.tier3
 var tint:=Color("b5bf51") if record.profile=="acid_water" else Color("bc91ce")
 material.albedo_color=tint.lerp(Color("638f8a"),float(record.suppression));plume.process_material.color=tint
 plume.amount_ratio=maxf(.05,1-float(record.suppression));plume.emitting=true
 label.text=record.rules.profiles[record.profile].name+"\n유입 억제 %.0f%% · %s"%[float(record.suppression)*100,record.source_status]
func _process(_dt: float) -> void:
 if marker==null:return
 var camera:=get_viewport().get_camera_3d()
 if camera==null:return
 var distance:=camera.global_position.distance_to(marker.global_position)
 marker.visible=distance<900;plume.emitting=distance<200;label.visible=distance<65
