class_name FrontierSurfaceHydrology
extends Node3D
## Fixed seeded tiles, bounded incremental tracing, shared INK water material.
var surface: FrontierCrewSurfaceScene
var cfg: Dictionary
var tiles: Dictionary={}
var jobs: Array[Dictionary]=[]
var material: ShaderMaterial
var ocean: MeshInstance3D
var native_liquid:=false
var anchor:=Vector2i(99999,99999)
var refresh:=0.0
var visible_segments:=0
var last_step_usec:=0
var maximum_step_usec:=0
var region: Dictionary={}
var region_key:=""
var occupied: Dictionary={}
var shoreline: Node3D
var water_quality:=1
var source_requests: Array[Dictionary]=[]
var foundations: Array[Vector4]=[]
var foundation_key:=""
func configure(owner_surface: FrontierCrewSurfaceScene) -> void:
 surface=owner_surface;cfg=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_hydrology.json"))
 native_liquid=FrontierSurfaceDrainage.liquid(surface.body.get("terrain_traits",{}))
 material=ShaderMaterial.new();material.shader=load("res://assets/materials/space/flow_water.gdshader")
 material.set_shader_parameter("water_color",Color(surface.body.get("traits",{}).get("sea","123d50")))
 if native_liquid:
  ocean=MeshInstance3D.new();ocean.name="Ocean";var plane:=PlaneMesh.new();plane.size=Vector2(16384,16384);ocean.mesh=plane
  ocean.position.y=float(cfg.sea_level);ocean.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  var sea_material:=ShaderMaterial.new();sea_material.shader=load("res://assets/materials/space/native_water.gdshader");sea_material.set_shader_parameter("water_color",Color(surface.body.traits.sea));ocean.material_override=sea_material;add_child(ocean)
 if native_liquid:
  shoreline=load("res://scripts/world/surface_shoreline.gd").new();add_child(shoreline);shoreline.configure(self)
 FrontierClientSettings.ensure(get_tree()).changed.connect(_quality_changed)
 _quality_changed()
 surface.terrain.geometry_changed.connect(invalidate)
func invalidate() -> void:
 # Removed support must not leave suspended water over a new excavation.
 for row in tiles.values():row.node.queue_free()
 tiles.clear();jobs.clear();source_requests.clear();occupied.clear();anchor=Vector2i(99999,99999);region_key=""
func accept(ledger: Dictionary) -> void:
 region=FrontierSurfaceRecovery.nearest_region(surface.body,ledger,surface.viewer.position)
 var buildings: Dictionary=ledger.get("sites",{}).get(surface.body.id,{}).get("buildings",{})
 var keys: Array=buildings.keys();keys.sort();var next_key:=""
 var next_foundations: Array[Vector4]=[]
 for id in keys:
  var row: Dictionary=buildings[id];next_key+=str([id,row.type,row.position])
  var at:=FrontierCrewWorld.vector(row.position)
  next_foundations.append(Vector4(at.x,at.y,at.z,float(FrontierCatalog.entry("buildings",row.type).radius)+.8))
 if next_key!=foundation_key:
  foundation_key=next_key;foundations=next_foundations;invalidate()
func _queue(key: String,tile: Vector2i,source: Vector3,managed: bool) -> void:
 if not source.is_finite() or source.y<float(cfg.sea_level) or tiles.has(key) or _protected(source):return
 var root:=Node3D.new();root.name="Catchment";add_child(root)
 tiles[key]={"node":root,"tile":tile,"managed":managed,"samples":PackedVector3Array(),"segments":0}
 jobs.append({"key":key,"at":source,"points":PackedVector3Array([source]),"levels":PackedFloat32Array([source.y+float(cfg.river_depth)]),"steps":0,"done":false,"basin":false,"stage":"trace","cursor":0,"vertices":PackedVector3Array(),"uvs":PackedVector2Array(),"colors":PackedColorArray(),"sections":[],"rim":PackedVector3Array()})
func _schedule() -> void:
 var p: Vector3=surface.viewer.position;var span:=float(cfg.tile_size)
 var next:=Vector2i(floori(p.x/span),floori(p.z/span))
 if next!=anchor:
  anchor=next
  for key in tiles.keys():
   if not tiles[key].managed:
    var offset: Vector2i=tiles[key].tile-anchor
    if maxi(absi(offset.x),absi(offset.y))>int(cfg.radius_tiles):tiles[key].node.queue_free();tiles.erase(key)
  for i in range(jobs.size()-1,-1,-1):
   if not tiles.has(jobs[i].key):jobs.remove_at(i)
  for cell in occupied.keys():
   if not tiles.has(occupied[cell]):occupied.erase(cell)
  source_requests.clear()
  if native_liquid:
   for x in range(anchor.x-int(cfg.radius_tiles),anchor.x+int(cfg.radius_tiles)+1):
    for z in range(anchor.y-int(cfg.radius_tiles),anchor.y+int(cfg.radius_tiles)+1):
     var tile:=Vector2i(x,z)
     for n in int(cfg.sources_per_tile):
      var key: String="%d:%d:%d"%[x,z,n]
      if not tiles.has(key):source_requests.append({"key":key,"tile":tile,"index":n})
 if ocean!=null:
  ocean.position.x=floorf(p.x/8)*8 if water_quality>0 else anchor.x*span
  ocean.position.z=floorf(p.z/8)*8 if water_quality>0 else anchor.y*span
 var regional_wet: float=0.0 if region.is_empty() else float(region.state.wet)
 if surface.presence!=null and not region.is_empty():regional_wet=maxf(regional_wet,float(surface.presence.state.wet))
 var next_region: String="" if region.is_empty() or regional_wet<.02 else str(region.center)
 if next_region!=region_key:
  region_key=next_region
  if tiles.has("managed"):tiles.managed.node.queue_free();tiles.erase("managed")
  for i in range(jobs.size()-1,-1,-1):
   if jobs[i].key=="managed":jobs.remove_at(i)
  if not region_key.is_empty() and not native_liquid:
   var best:=Vector3(0,-INF,0)
   for i in 16:
    var q: Vector3=region.center+Vector3(cos(i*TAU/16),0,sin(i*TAU/16))*float(region.radius)*.65
    q.y=surface.terrain.field.height(q.x,q.z)
    if q.y>best.y and Vector2(q.x,q.z).length()>25:best=q
   _queue("managed",anchor,best,true)
func _process(delta: float) -> void:
 if surface==null or not surface.session.active:return
 var app=surface.get_parent()
 if app is FrontierCrewExpedition and (app.any_menu_open() or (not get_window().has_focus() and not app.test_mode)):return
 var started:=Time.get_ticks_usec()
 refresh-=delta
 if refresh<=0:refresh=.5;_schedule()
 material.set_shader_parameter("flow_time",surface.presence.clock_value if surface.presence!=null else 0.0)
 if ocean!=null:ocean.material_override.set_shader_parameter("flow_time",surface.presence.clock_value if surface.presence!=null else 0.0)
 if tiles.has("managed") and surface.presence!=null:
  for visual in tiles.managed.node.get_children():visual.set_instance_shader_parameter("water_amount",float(surface.presence.state.wet))
 if shoreline!=null:shoreline.update(delta)
 if not source_requests.is_empty():
  var source: Dictionary=source_requests.pop_front()
  _queue(source.key,source.tile,FrontierSurfaceDrainage.source(surface.terrain.field,source.tile,source.index,cfg),false)
 if jobs.is_empty():
  last_step_usec=Time.get_ticks_usec()-started;maximum_step_usec=maxi(maximum_step_usec,last_step_usec);return
 var job: Dictionary=jobs[0]
 if job.stage=="trace":
  for n in int(cfg.steps_per_frame):
   _step(job)
   if job.done:job.stage="sections";break
 elif job.stage=="sections":
  _section_step(job)
 elif job.stage=="lake":
  _lake_step(job)
 else:
  _install(job);jobs.pop_front()
 last_step_usec=Time.get_ticks_usec()-started;maximum_step_usec=maxi(maximum_step_usec,last_step_usec)
func _protected(p: Vector3) -> bool:
 if Vector2(p.x,p.z).length()<24:return true
 for area in foundations:
  if Vector2(p.x-area.x,p.z-area.z).length()<area.w+float(cfg.river_half_width):return true
 return false
func _step(job: Dictionary) -> void:
 var field:=surface.terrain.field;var at: Vector3=job.at
 var next:=FrontierSurfaceDrainage.advance(field,at,cfg)
 job.steps+=1
 if next==at:job.done=true;job.basin=true;return
 if _protected(next) or field.density(next-Vector3.UP*.4)<0:job.done=true;return
 if tiles[job.key].managed and (region.is_empty() or FrontierSurfaceRecovery.weight(next,region.center,region.radius)<.12):job.done=true;return
 var level:=minf(float(job.levels[-1]),next.y+float(cfg.river_depth))
 if native_liquid:level=maxf(float(cfg.sea_level),level)
 job.points.append(next);job.levels.append(level);job.at=next
 var cell:=Vector2i(roundi(next.x/float(cfg.step_meters)),roundi(next.z/float(cfg.step_meters)))
 if occupied.has(cell) and occupied[cell]!=job.key:job.done=true
 else:occupied[cell]=job.key
 if native_liquid and next.y<float(cfg.sea_level):job.levels[-1]=float(cfg.sea_level);job.done=true
 if job.steps>=int(cfg.maximum_steps):job.done=true
func _section_step(job: Dictionary) -> void:
 var points: PackedVector3Array=job.points
 var i:=int(job.cursor)
 if i>=points.size():
  job.stage="lake" if job.basin and points.size()>2 else "install";job.cursor=0;return
 var at: Vector3=points[i]
 if i>0 and i<points.size()-1:
  var smooth: Vector3=points[i-1]*.2+at*.6+points[i+1]*.2
  var ground:=surface.terrain.field.height(smooth.x,smooth.z)
  if ground<float(job.levels[i])-.025:at=Vector3(smooth.x,ground,smooth.z)
 var direction: Vector3=points[mini(points.size()-1,i+1)]-points[maxi(0,i-1)]
 var section:=FrontierSurfaceDrainage.section(surface.terrain.field,at,direction,job.levels[i],cfg)
 job.sections.append(section)
 if i>0:
  var a: PackedVector3Array=job.sections[i-1];var b:=section
  for v in [0,2,1,1,2,3]:
   job.vertices.append([a[0],a[1],b[0],b[1]][v]);job.uvs.append(Vector2(v%2,float(i-1+v/2)*float(cfg.step_meters)));job.colors.append(Color.WHITE)
  tiles[job.key].samples.append((a[0]+a[1])*.5);tiles[job.key].segments+=1
 job.cursor+=1
func _lake_step(job: Dictionary) -> void:
 var at: Vector3=job.points[-1];var level:=float(job.levels[-1]);var i:=int(job.cursor)
 if i>=24:
  for n in 24:
   for q in [Vector3(at.x,level,at.z),job.rim[(n+1)%24],job.rim[n]]:
    job.vertices.append(q);job.uvs.append(Vector2(q.x-at.x,q.z-at.z)*.15);job.colors.append(Color(.0,1,1,1))
  job.stage="install";return
 var direction:=Vector3(cos(i*TAU/24),0,sin(i*TAU/24));var edge:=at
 for n in 14:
  var q:=at+direction*(n+1)*float(cfg.lake_radius)/14.0
  if surface.terrain.field.height(q.x,q.z)>level or surface.terrain.field.density(q-Vector3.UP*.4)<0:break
  edge=q
 edge.y=level;job.rim.append(edge);job.cursor+=1
func _install(job: Dictionary) -> void:
 if not tiles.has(job.key) or job.vertices.is_empty():return
 var row: Dictionary=tiles[job.key]
 var arrays:=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=job.vertices;arrays[Mesh.ARRAY_TEX_UV]=job.uvs;arrays[Mesh.ARRAY_COLOR]=job.colors
 var normals:=PackedVector3Array();normals.resize(job.vertices.size());normals.fill(Vector3.UP);arrays[Mesh.ARRAY_NORMAL]=normals
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var visual:=MeshInstance3D.new();visual.mesh=mesh;visual.material_override=material;visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 visual.visibility_range_end=float(cfg.visible_distance);visual.visibility_range_end_margin=60;visual.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF;row.node.add_child(visual)
 visible_segments+=row.segments
func nearest_water(p: Vector3) -> Dictionary:
 var result: Dictionary=surface.physical_water.nearest_water(p) if surface.physical_water!=null else {"distance":INF,"position":p,"kind":""}
 if native_liquid:
  for i in 12:
   var q:=p+Vector3(cos(i*TAU/12),0,sin(i*TAU/12))*12;q.y=float(cfg.sea_level)
   if surface.terrain.field.height(q.x,q.z)<q.y and p.distance_to(q)<float(result.distance):result={"distance":p.distance_to(q),"position":q,"kind":"ocean"}
 for row in tiles.values():
  if row.node.get_child_count()==0:continue
  for q in row.samples:
   var d:=p.distance_to(q)
   if d<float(result.distance):result={"distance":d,"position":q,"kind":"river"}
 return result

func _quality_changed() -> void:
 water_quality=FrontierWaterQuality.level(get_tree())
 FrontierWaterQuality.apply(material,water_quality)
 if ocean!=null:
  ocean.mesh=FrontierWaterQuality.ocean_mesh(water_quality);ocean.extra_cull_margin=.2
  FrontierWaterQuality.apply(ocean.material_override,water_quality)
