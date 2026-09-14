extends RefCounted
const Bake=preload("res://scripts/ui/planet_map_bake.gd")
var tiles: Dictionary={}
var wanted: Array=[]
var job: RefCounted
var task: int=-1
var scope:=""
var level:=0
var completed:=0
func request(field: FrontierTerrainField,body: Dictionary,focus: Vector2,extent: Vector2,scale: float) -> void:
 var next_scope:=str([body.id,field.seed_value])
 if next_scope!=scope:scope=next_scope;tiles.clear()
 level=clampi(roundi(log(maxf(.25,scale))/log(2.0)),-4,6)
 var span:=256.0*pow(2,level)
 var minimum:=((focus-extent*.5)/span).floor()
 var maximum:=((focus+extent*.5)/span).floor()
 wanted.clear();completed=0
 for z in range(int(minimum.y),int(maximum.y)+1):
  for x in range(int(minimum.x),int(maximum.x)+1):
   var origin:=Vector2(x,z)*span
   if origin.x>8192 or origin.y>8192 or origin.x+span< -8192 or origin.y+span< -8192:continue
   var key:=str([scope,level,x,z])
   wanted.append({"key":key,"origin":origin,"span":span})
   if tiles.has(key):completed+=1;tiles[key].used=Time.get_ticks_msec()
 wanted.sort_custom(func(a,b):return (a.origin+Vector2.ONE*a.span*.5).distance_squared_to(focus)<(b.origin+Vector2.ONE*b.span*.5).distance_squared_to(focus))
 if task>=0:return
 for row in wanted:
  if tiles.has(row.key):continue
  job=Bake.new();job.resolution=Vector2i(64,64);job.configure(field,body,row.origin,Vector2.ONE*row.span,row.key)
  job.set_meta("scope",scope);job.set_meta("level",level)
  task=WorkerThreadPool.add_task(job.run,false,"Regional cartography tile");return
func poll() -> bool:
 if task<0 or not WorkerThreadPool.is_task_completed(task):return false
 WorkerThreadPool.wait_for_task_completion(task);task=-1
 if job.get_meta("scope")==scope:
  tiles[job.key]={"texture":ImageTexture.create_from_image(job.result),"origin":job.map_min,"span":job.map_size.x,"level":job.get_meta("level"),"ready":Time.get_ticks_msec(),"used":Time.get_ticks_msec()}
  if tiles.size()>192:
   var oldest:="";var age:=9223372036854775807
   for key in tiles:
    if not wanted.any(func(row):return row.key==key) and int(tiles[key].used)<age:age=tiles[key].used;oldest=key
   if not oldest.is_empty():tiles.erase(oldest)
 job=null;return true
func draw(canvas: Control,focus: Vector2,scale: float) -> void:
 var ordered:=tiles.values();ordered.sort_custom(func(a,b):return int(a.level)>int(b.level))
 for row in ordered:
  var rect:=Rect2(canvas.size*.5+(row.origin-focus)/scale,Vector2.ONE*row.span/scale)
  if not rect.intersects(Rect2(Vector2.ZERO,canvas.size)):continue
  var age:=clampf((Time.get_ticks_msec()-int(row.ready))/500.0,0,1)
  if age>=1:canvas.draw_texture_rect(row.texture,rect,false,Color(1,1,1,.9));continue
  # Newly decoded tiles open radially; previously cached tiles remain visible.
  var circle:=PackedVector2Array()
  for i in 40:circle.append(rect.get_center()+Vector2.from_angle(TAU*i/40.0)*rect.size.length()*.5*age)
  var corners:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
  for poly in Geometry2D.intersect_polygons(corners,circle):
   var uv:=PackedVector2Array()
   for point in poly:uv.append((point-rect.position)/rect.size)
   canvas.draw_polygon(poly,PackedColorArray([Color(1,1,1,.9)]),uv,row.texture)
func finish() -> void:
 if task>=0:WorkerThreadPool.wait_for_task_completion(task);task=-1;job=null
