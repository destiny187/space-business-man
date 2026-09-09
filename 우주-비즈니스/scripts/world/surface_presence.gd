class_name FrontierSurfacePresence
extends Node3D
## Local scenery, saved-state driven growth, coherent wind and bounded interaction traces.
var surface: FrontierCrewSurfaceScene
var cfg: Dictionary
var region: Dictionary={}
var state: Dictionary={"grass":0.0,"trees":0.0,"wet":0.0,"life":0.0}
var patches: Array[Dictionary]=[]
var ponds: Array[Dictionary]=[]
var traces: Array[Dictionary]=[]
var lights: Dictionary={}
var style_cache: Dictionary={}
var materials: Array[ShaderMaterial]=[]
var clock_value:=0.0
var gust:=0.0
var wind:=Vector3.RIGHT
var shelter:=1.0
var cave:=0.0
var sample_timer:=0.0
var previous:=Vector3.INF
var stride:=0.0
var foot:=1.0
var assets_ready:=false
var request: Dictionary={}
var sounds: Node
var signature:=""
var plant_instances:=0
var scenery: Node3D
var presentation_timer:=0.0
var cover_rng:=RandomNumberGenerator.new()
var cover_models: Dictionary={}
var grass_meshes: Array[Dictionary]=[]
func configure(owner_surface: FrontierCrewSurfaceScene) -> void:
 surface=owner_surface;cfg=FrontierSurfaceRecovery.config()
 for kind in ["grass","tree"]:
  var path: String=cfg[kind+"_model"];ResourceLoader.load_threaded_request(path);request[kind]=path
 surface.terrain.geometry_changed.connect(_invalidate_ground)
 sounds=load("res://scripts/world/surface_soundscape.gd").new();add_child(sounds);sounds.configure(self)
 scenery=load("res://scripts/world/surface_scenery.gd").new();add_child(scenery);scenery.configure(self)
 accept(surface.business_view.ledger)
func accept(ledger: Dictionary) -> void:
 region=FrontierSurfaceRecovery.region(surface.body,ledger)
 var next: String=surface.surface_details.building_signature
 if next!=signature:signature=next;sample_timer=0;_invalidate_ground()
func _invalidate_ground() -> void:
 for row in traces:row.node.queue_free()
 traces.clear()
 for row in patches:row.checked=false
 for row in ponds:row.checked=false
func _blocked(p: Vector3) -> bool:
 if Vector2(p.x-surface.landing_ship.position.x,p.z-surface.landing_ship.position.z).length()<15:return true
 if Vector2(p.x,p.z).length()<9:return true
 for area in surface.surface_details.exclusions:
  if Vector2(p.x-area.x,p.z-area.z).length()<area.w+float(cfg.patch_radius):return true
 # Keep real resource nodes readable and reachable.
 for node in surface.business_view.nodes.values():
  if node.get_meta("business_kind","")=="vein" and node.position.distance_to(p)<3:return true
 return false
func _load() -> void:
 if assets_ready or region.is_empty():return
 if cover_models.is_empty():
  for path in request.values():
   if ResourceLoader.load_threaded_get_status(path)!=ResourceLoader.THREAD_LOAD_LOADED:return
  for kind in request:cover_models[kind]=ResourceLoader.load_threaded_get(request[kind])
  cover_rng.seed=FrontierUniverse.derive(int(surface.body.seed),"recovery-cover-v1")
  var prototype: Node3D=cover_models.grass.instantiate();_style(prototype,true)
  for source in prototype.find_children("*","MeshInstance3D",true,false):
   var mesh: Mesh=source.mesh.duplicate()
   for j in mesh.get_surface_count():mesh.surface_set_material(j,source.get_active_material(j))
   grass_meshes.append({"mesh":mesh,"transform":source.transform})
  prototype.free()
 var rng:=cover_rng
 if patches.size()<int(cfg.patch_count):
  var angle:=rng.randf()*TAU;var distance_value:=sqrt(rng.randf())*float(region.radius)*.92
  var at: Vector3=region.center+Vector3(cos(angle),0,sin(angle))*distance_value
  var root:=Node3D.new();add_child(root)
  var grass_root:=Node3D.new();root.add_child(grass_root)
  var placements: Array[Transform3D]=[]
  for n in int(cfg.grass_per_patch):
   var local_at:=Vector3(rng.randf_range(-cfg.patch_radius,cfg.patch_radius),0,rng.randf_range(-cfg.patch_radius,cfg.patch_radius))
   placements.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*float(cfg.grass_scale)*rng.randf_range(.7,1.3)),local_at));plant_instances+=1
  for source in grass_meshes:
   var mesh: Mesh=source.mesh
   var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=placements.size()
   var visual:=MultiMeshInstance3D.new();visual.multimesh=mm;visual.set_meta("source_transform",source.transform);grass_root.add_child(visual)
   visual.visibility_range_end=float(cfg.visible_distance);visual.visibility_range_end_margin=18;visual.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
   for j in placements.size():mm.set_instance_transform(j,placements[j]*source.transform)
  var tree: Node3D=cover_models.tree.instantiate();root.add_child(tree);tree.scale=Vector3.ONE*float(cfg.tree_scale)*rng.randf_range(.8,1.25);tree.rotation.y=rng.randf()*TAU;_style(tree,true)
  patches.append({"samples":placements,"node":root,"grass":grass_root,"tree":tree,"tree_scale":tree.scale,"point":at,"threshold":rng.randf_range(.05,.8),"phase":rng.randf()*TAU,"growth":0.0,"wood":0.0,"checked":false,"valid":false})
  root.visible=false
  return
 # Small terrain-conforming wet hollows. They never create a collision or resource.
 for i in int(cfg.water_patch_count):
  var angle:=float(i)*TAU/float(cfg.water_patch_count)+rng.randf()
  var at: Vector3=region.center+Vector3(cos(angle),0,sin(angle))*rng.randf_range(17,float(region.radius)*.8)
  var water:=MeshInstance3D.new();water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(water)
  var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/recovery_water.gdshader");water.material_override=mat;water.visible=false
  ponds.append({"node":water,"point":at,"material":mat,"checked":false,"valid":false,"strength":0.0})
 assets_ready=true
func _style(root: Node3D,foliage: bool) -> void:
 FrontierInkStyle.apply(root,style_cache)
 for node in root.find_children("*","MeshInstance3D",true,false):
  node.visibility_range_end=float(cfg.visible_distance);node.visibility_range_end_margin=18;node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
  for i in node.mesh.get_surface_count():
   var old: Material=node.get_active_material(i)
   if old is ShaderMaterial:
    var mat: ShaderMaterial=old;mat.set_shader_parameter("presence_foliage",foliage)
    if mat not in materials:materials.append(mat)
func _ground(row: Dictionary,water: bool=false) -> void:
 var p: Vector3=row.point;p.y=surface.terrain.field.height(p.x,p.z)
 if not surface.terrain.ready_at(p+Vector3.UP):return
 row.node.visible=false
 row.checked=true;row.valid=not _blocked(p) and surface.terrain.field.normal(p).y>float(cfg.minimum_normal_y) and surface.terrain.field.density(p-Vector3.UP*.2)>0
 if float(surface.body.traits.get("water",0))>15 and float(surface.body.traits.get("temperature",0))>0 and p.y< -3.9:row.valid=false
 if not row.valid:return
 row.node.position=p
 if water:
  var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  var size: float=cfg.water_patch_radius;var steps:=6
  for x in steps:
   for z in steps:
    for v in [Vector2(x,z),Vector2(x,z+1),Vector2(x+1,z),Vector2(x+1,z),Vector2(x,z+1),Vector2(x+1,z+1)]:
     var offset: Vector3=Vector3((v.x/steps-.5)*size*2,0,(v.y/steps-.5)*size*2)
     var h:=surface.terrain.field.height(p.x+offset.x,p.z+offset.z)
     if absf(h-p.y)>.75:row.valid=false
     st.set_uv(v/steps);st.set_normal(surface.terrain.field.normal(Vector3(p.x+offset.x,h,p.z+offset.z)));st.add_vertex(offset+Vector3.UP*(h-p.y+.025))
  row.node.mesh=st.commit()
 else:
  for j in row.samples.size():
   var placement: Transform3D=row.samples[j]
   var q: Vector3=p+placement.origin;q.y=surface.terrain.field.height(q.x,q.z)
   placement.origin.y=q.y-p.y
   if _blocked(q) or absf(q.y-p.y)>1.5 or surface.terrain.field.normal(q).y<.8:placement.basis=placement.basis.scaled(Vector3.ONE*.001)
   for visual in row.grass.get_children():visual.multimesh.set_instance_transform(j,placement*visual.get_meta("source_transform"))
func _process(delta: float) -> void:
 if surface==null or not surface.session.active:return
 var app=surface.get_parent();var blocked:=false
 if app is FrontierCrewExpedition:blocked=app.any_menu_open() or app.arrival.active or (not get_window().has_focus() and not app.test_mode)
 var shared: float=surface.atmosphere.clock_seconds
 var phase_value:=float(int(surface.body.seed)%1000)*.013
 gust=(.025+.975*pow(maxf(0.0,sin(shared/float(cfg.wind_period_seconds)*TAU+phase_value)),3))*float(surface.atmosphere.current.atmosphere)
 wind=Vector3(cos(phase_value+sin(shared*.007)*.2),0,sin(phase_value+sin(shared*.007)*.2))
 if not blocked:clock_value+=delta
 _load()
 if not region.is_empty():
  for key in state:state[key]=lerpf(float(state[key]),float(region.state[key]),1-exp(-delta/float(cfg.transition_seconds)))
  surface.terrain.material.set_shader_parameter("recovery_water",float(region.environment.water)/100.0)
  surface.terrain.material.set_shader_parameter("recovery_pressure",float(region.environment.pressure))
  surface.terrain.material.set_shader_parameter("recovery_life",state.grass)
 sample_timer-=delta
 if sample_timer<=0:
  sample_timer=.35;_sample_shelter();_industry()
  for row in patches:
   if not row.checked:_ground(row);break
  for row in ponds:
   if not row.checked:_ground(row,true);break
 for row in patches:
  if not row.valid:continue
  var weight_value:=0.0 if region.is_empty() else FrontierSurfaceRecovery.weight(row.point,region.center,region.radius)
  var target:=smoothstep(row.threshold,row.threshold+.2,float(state.grass)*weight_value)
  # Building and excavation invalidation rechecks support on the bounded sample tick.
  row.growth=move_toward(float(row.growth),target,delta/float(cfg.growth_seconds))
  row.wood=move_toward(float(row.wood),smoothstep(row.threshold,row.threshold+.25,float(state.trees)*weight_value) if target>0 else 0,delta/(float(cfg.growth_seconds)*2))
  row.node.visible=row.growth>.01 or row.wood>.01
  row.grass.scale=Vector3.ONE*maxf(.001,row.growth);row.tree.scale=row.tree_scale*maxf(.001,row.wood);row.tree.visible=row.wood>.02
 for row in ponds:
  if not row.valid:continue
  row.strength=move_toward(float(row.strength),float(state.wet)*FrontierSurfaceRecovery.weight(row.point,region.center,region.radius) if not region.is_empty() else 0,delta*.1)
  row.node.visible=row.strength>.04;row.material.set_shader_parameter("amount",row.strength);row.material.set_shader_parameter("flow_time",clock_value);row.material.set_shader_parameter("gust",gust)
 presentation_timer-=delta
 if presentation_timer<=0:
  presentation_timer=.05
  for mat in materials:
   mat.set_shader_parameter("presence_time",clock_value);mat.set_shader_parameter("presence_wind",Vector2(wind.x,wind.z)*gust)
 _traces(delta,blocked)
 scenery.update(delta,blocked)
 sounds.update(delta,blocked)
func _sample_shelter() -> void:
 var p: Vector3=surface.viewer.position+Vector3.UP*1.6
 cave=clampf((surface.terrain.field.height(p.x,p.z)-p.y)/5,0,1)
 var cover:=0.0
 for d in [3.0,7.0,12.0]:
  if surface.terrain.field.density(p-wind*d)>0:cover+=.28
 var query:=PhysicsRayQueryParameters3D.create(p,p-wind*12)
 if surface.viewer is CollisionObject3D:query.exclude=[surface.viewer.get_rid()]
 var hit:=get_world_3d().direct_space_state.intersect_ray(query)
 if not hit.is_empty():cover=maxf(cover,.8 if p.distance_to(hit.position)<5 else .55)
 shelter=(1-cover)*(1-cave)
func _industry() -> void:
 for id in lights.keys():
  if not surface.business_view.nodes.has(id):
   if is_instance_valid(lights[id]):lights[id].queue_free()
   lights.erase(id)
 for id in surface.business_view.nodes:
  var node: Node3D=surface.business_view.nodes[id]
  if node.get_meta("business_kind","")!="building":continue
  if not lights.has(id):
   if lights.size()>=8:continue
   var light:=OmniLight3D.new();light.light_color=Color("a7e3dd");light.omni_range=6;light.light_energy=0;node.add_child(light);light.position=Vector3(0,2.4,0);lights[id]=light
  lights[id].light_energy=(.65+.08*sin(clock_value*2+float(hash(id)%100)))*(1-surface.atmosphere.daylight*.7) if node.get_meta("working",false) else 0.0
func mark(point: Vector3,direction: Vector3,kind: float=0.0) -> void:
 if not point.is_finite():return
 if traces.size()>=int(cfg.trace_count):
  if traces.is_empty():return
  traces[0].node.queue_free();traces.pop_front()
 var p:=point;p.y=surface.terrain.field.height(p.x,p.z)+.026
 if absf(p.y-point.y)>(4.0 if kind==1 else 1.0):return
 var node:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(.24,.44) if kind==0 else (Vector2(.3,1.2) if kind==2 else (Vector2(8,8) if kind==3 else Vector2(1.1,1.1)));node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var mat:=ShaderMaterial.new();mat.shader=load("res://assets/materials/space/surface_trace.gdshader");mat.set_shader_parameter("kind",kind);mat.set_shader_parameter("trace_color",Color("748e98") if float(surface.body.traits.temperature)<0 else Color(surface.body.traits.dust).darkened(.48));node.material_override=mat;add_child(node)
 node.position=p;node.basis=Basis(Quaternion(Vector3.UP,surface.terrain.field.normal(p)))*Basis(Vector3.UP,atan2(direction.x,direction.z))
 traces.append({"node":node,"material":mat,"age":0.0})
 if kind==1 and scenery!=null:scenery.puff(p,8)
func _traces(delta: float,blocked: bool) -> void:
 if not blocked:
  var p: Vector3=surface.viewer.position
  var app=surface.get_parent()
  var driving: bool=app is FrontierCrewExpedition and not app.rovers.seat().is_empty()
  if driving:p.y=surface.terrain.field.height(p.x,p.z)
  if previous.is_finite():
   var displacement:=p-previous
   if displacement.length()<3 and absf(p.y-surface.terrain.field.height(p.x,p.z))<.5:
    stride+=Vector2(displacement.x,displacement.z).length()
    if stride>.9:
     var side:=Vector3(-displacement.z,0,displacement.x).normalized()
     if driving:mark(p+side*.85,displacement,2);mark(p-side*.85,displacement,2)
     else:mark(p+side*foot*.13,displacement)
     stride=0;foot*=-1
  previous=p
 for row in traces:
  if not blocked:row.age+=delta*(1+gust*.8)
  row.material.set_shader_parameter("fade",1-smoothstep(float(cfg.trace_seconds)*.65,float(cfg.trace_seconds),row.age))
 for i in range(traces.size()-1,-1,-1):
  if traces[i].age>float(cfg.trace_seconds):traces[i].node.queue_free();traces.remove_at(i)
func local_weight() -> float:
 return 0.0 if region.is_empty() else FrontierSurfaceRecovery.weight(surface.viewer.position,region.center,region.radius)
