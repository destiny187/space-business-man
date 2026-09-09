extends Node3D
## Bounded mid-distance weather, source-backed foley and shared vegetation motion.
var presence: FrontierSurfacePresence
var haze: MultiMeshInstance3D
var haze_mat: ShaderMaterial
var motes: MultiMeshInstance3D
var mote_mat: ShaderMaterial
var wisps: Array[Dictionary]=[]
var grains: Array[Dictionary]=[]
var clock_value:=0.0
var tick:=0.0
var anchor:=Vector2i(9999,9999)
var rock_sources: Array[Vector3]=[]
var plant_sources: Array[Vector3]=[]
var plant_materials: Array[ShaderMaterial]=[]
var water: Dictionary={"distance":INF,"position":Vector3.ZERO,"kind":""}
var machines: Array[Node3D]=[]
var animation_left:=0.0
var rng:=RandomNumberGenerator.new()
func configure(owner_presence: FrontierSurfacePresence) -> void:
 presence=owner_presence;rng.seed=FrontierUniverse.derive(int(presence.surface.body.seed),"surface-weather-v1")
 haze=_batch(12);haze_mat=haze.multimesh.mesh.material
 motes=_batch(48);mote_mat=motes.multimesh.mesh.material;mote_mat.shader=load("res://assets/materials/space/surface_grain.gdshader")
 for i in 12:wisps.append({"point":Vector3.ZERO,"valid":false,"phase":rng.randf()*TAU})
 for i in 48:grains.append({"point":Vector3.ZERO,"velocity":Vector3.ZERO,"age":10.0,"tint":Color.WHITE,"fall":.6})
func _batch(count: int) -> MultiMeshInstance3D:
 var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/landing_dust.gdshader")
 var quad:=QuadMesh.new();quad.material=mat
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=quad;mm.instance_count=count
 var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
 for i in count:mm.set_instance_color(i,Color(1,1,1,0))
 return node
func sample() -> void:
 var s:=presence.surface;var p: Vector3=s.viewer.position
 for mat in s.surface_details.material_cache.values():
  if mat is ShaderMaterial:mat.set_shader_parameter("contact_wet",maxf(float(s.body.traits.water)/100.0*.4,float(presence.state.wet)*presence.local_weight()))
 rock_sources.clear();plant_sources.clear();plant_materials.clear();machines.clear()
 for row in s.surface_details.tiles.values():
  for q in row.get("sources",[]):
   if p.distance_squared_to(q)<900:rock_sources.append(q)
 for id in s.ecology.actors:
  var actor: Node3D=s.ecology.actors[id]
  if p.distance_squared_to(actor.position)>6400 or s.ecology.encounters[id].status!="active":continue
  if FrontierEcologyCatalog.form(s.ecology.encounters[id].form_id).category!="plant":continue
  plant_sources.append(actor.position)
  for group in actor.material_slots.values():
   for mat in group:
    mat.set_shader_parameter("presence_foliage",true)
    if mat not in plant_materials:plant_materials.append(mat)
 for id in s.business_view.nodes:
  var node: Node3D=s.business_view.nodes[id]
  if node.get_meta("business_kind","")!="building" or p.distance_squared_to(node.position)>10000:continue
  var record: Dictionary=s.business_view.ledger.get("sites",{}).get(s.body.id,{}).get("buildings",{}).get(id,{})
  var type_id: String=record.get("type","")
  var running: bool=record.get("working",false) if type_id in ["atmosphere","thermal","water","biolab"] else type_id=="factory" and not record.get("production",{}).is_empty()
  if not running or not record.get("active",false):continue
  node.set_meta("scenery_sound",{"atmosphere":"sfx_terraform_active","thermal":"sfx_thermal_loop","water":"sfx_water_loop","biolab":"sfx_biolab_loop"}.get(type_id,"sfx_robot_work"));machines.append(node)
 machines.sort_custom(func(a: Node3D,b: Node3D)->bool:return p.distance_squared_to(a.position)<p.distance_squared_to(b.position))
 if machines.size()>4:machines.resize(4)
 for machine in machines:
  if p.distance_squared_to(machine.position)>1225:continue
  var vent: Vector3=machine.position+Vector3.UP*2.5
  for part in machine.get_meta("parts",[]):
   if str(part.name).begins_with("Anim_Fan"):vent=part.global_position+Vector3.UP*.15;break
  puff(vent,1,Color("bac9c6"),true)
 if s.hydrology!=null:water=s.hydrology.nearest_water(p)
 var next:=Vector2i(floori(p.x/24),floori(p.z/24))
 if next!=anchor:
  anchor=next
  for i in wisps.size():
   var angle:=i*TAU/wisps.size()+float(int(s.body.seed)%31)
   var q:=Vector3(anchor.x*24,0,anchor.y*24)+Vector3(cos(angle),0,sin(angle))*(35+float(i%3)*18)
   q.y=s.terrain.field.height(q.x,q.z)+.7
   wisps[i].point=q;wisps[i].valid=s.terrain.field.density(q-Vector3.UP)>0
func update(delta: float,blocked: bool) -> void:
 if blocked:return
 tick-=delta
 if tick<=0:tick=.5;sample()
 clock_value+=delta
 animation_left-=delta
 if animation_left>0:return
 delta=.05;animation_left=.05
 var s:=presence.surface;var air: float=s.atmosphere.current.atmosphere
 var damp: float=maxf(float(s.atmosphere.current.mist),float(presence.state.wet)*presence.local_weight()*.25)
 var dust: float=float(s.atmosphere.current.dust)*presence.gust
 var amount: float=maxf(damp*.25,dust)*air*(1-presence.cave)
 var quality: int=s.preferences.quality_level("effects")
 haze.multimesh.visible_instance_count=6 if quality==0 else 12
 motes.multimesh.visible_instance_count=24 if quality==0 else 48
 haze.visible=amount>.005
 var tint: Color=s.atmosphere.current.dust_color.lerp(s.atmosphere.current.cloud_color,clampf(damp,0,1))
 haze_mat.set_shader_parameter("tint",tint);mote_mat.set_shader_parameter("tint",Color.WHITE)
 for i in wisps.size():
  var row: Dictionary=wisps[i]
  var q: Vector3=row.point+presence.wind*sin(clock_value*.11+row.phase)*2.5
  var fade: float=(.6+.4*sin(clock_value*.17+row.phase))*amount if row.valid else 0.0
  haze.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(12,2.2,1)),q))
  haze.multimesh.set_instance_color(i,Color(1,1,1,fade*.32))
 for mat in plant_materials:
  mat.set_shader_parameter("presence_time",presence.clock_value);mat.set_shader_parameter("presence_wind",Vector2(presence.wind.x,presence.wind.z)*presence.gust)
 for i in grains.size():
  var grain: Dictionary=grains[i];grain.age+=delta
  if grain.age>2.5:motes.multimesh.set_instance_color(i,Color(1,1,1,0));continue
  grain.velocity+=Vector3.DOWN*delta*float(grain.fall)+presence.wind*presence.gust*delta*.2;grain.point+=grain.velocity*delta
  motes.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*(.16+grain.age*.25)),grain.point))
  motes.multimesh.set_instance_color(i,Color(grain.tint.r,grain.tint.g,grain.tint.b,(1-grain.age/2.5)*.75))
func puff(at: Vector3,count: int=5,tint: Color=Color.TRANSPARENT,steam: bool=false) -> void:
 var left:=count
 for row in grains:
  if row.age<2.5:continue
  row.point=at+Vector3(0,.15,0);row.velocity=Vector3(rng.randf_range(-.7,.7),rng.randf_range(.2,.7),rng.randf_range(-.7,.7))+presence.wind*presence.gust;row.age=0.0;row.tint=Color(presence.surface.body.traits.dust) if tint.a==0 else tint;row.fall=.03 if steam else .6;left-=1
  if left<=0:break
