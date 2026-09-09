class_name FrontierSurfaceWater
extends RefCounted
## Sparse finite-volume cells. Only reservoirs add/remove mass; solid faces never transmit it.
## One metre cells use slight compression to propagate hydrostatic pressure uphill.
static var _cfg: Dictionary={}
static func config() -> Dictionary:
 if _cfg.is_empty():_cfg=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_water_physics.json"))
 return _cfg
static func create() -> Dictionary:return {"version":1,"serial":0,"cells":{}}
static func key(p: Vector3i) -> String:return "%d:%d:%d"%[p.x,p.y,p.z]
static func cell(p: Vector3) -> Vector3i:return Vector3i(floori(p.x),floori(p.y),floori(p.z))
static func point(k: String) -> Vector3i:
 var parts:=k.split(":");return Vector3i(int(parts[0]),int(parts[1]),int(parts[2]))
static func valid(value: Variant,limit: int=16384) -> bool:
 if not value is Dictionary or value.get("version")!=1 or not FrontierUniverse._finite(value.get("serial"),0,9007199254740000) or not value.get("cells") is Dictionary or value.cells.size()>limit:return false
 for k in value.cells:
  if not k is String or k.length()>48:return false
  var parts: PackedStringArray=k.split(":")
  if parts.size()!=3:return false
  for part in parts:
   if not part.is_valid_int() or abs(int(part))>1000000:return false
  if key(point(k))!=k:return false
  var row: Variant=value.cells[k]
  if not row is Array or row.size()!=2 or not FrontierUniverse._finite(row[0],0,float(config().maximum_mass)) or not FrontierUniverse._finite(row[1],0,1):return false
 return true
static func validate_world(world: Dictionary) -> String:
 var water: Variant=world.get("surface_water",{})
 if not water is Dictionary:return "행성 물 저장 형식 오류"
 for id in water:
  if not id is String or FrontierUniverse.ordinal_of(world.manifest,id)<0 or not valid(water[id],int(config().maximum_cells_per_planet)):return "행성 물 부피·좌표 오류"
 return ""
static func depth(record: Dictionary,p: Vector3) -> float:
 var c:=cell(p);var result:=0.0
 for y in range(c.y,c.y+3):
  var row: Array=record.get("cells",{}).get(key(Vector3i(c.x,y,c.z)),[])
  if row.is_empty():continue
  var bottom:=float(y)+float(row[1]);var top:=float(y)+minf(1.0,float(row[1])+float(row[0]))
  if top>p.y and bottom<=p.y+result+.12:result=maxf(result,top-p.y)
 return result
static func packet(record: Dictionary,p: Vector3) -> Dictionary:
 var result:=create();result.serial=record.get("serial",0)
 var nearby: Array=[]
 for k in record.get("cells",{}):
  var d:=Vector3(point(k)).distance_squared_to(p)
  if d<=pow(float(config().snapshot_radius),2):nearby.append([d,k])
 nearby.sort_custom(func(a: Array,b: Array):return a[0]<b[0])
 for i in mini(nearby.size(),int(config().snapshot_cells)):
  var k: String=nearby[i][1];result.cells[k]=record.cells[k].duplicate()
 return result

var field: FrontierTerrainField
var original: FrontierTerrainField
var record: Dictionary
var native:=false
var ocean_level:=-4.0
var cache: Dictionary={}
var faces: Dictionary={}
var queue: Array[String]=[]
var queued: Dictionary={}
var cursor:=0
var interests: Array[Vector3]=[]
var edits_seen:=0
var edit_bounds: Array[Vector4]=[]
var seed_jobs: Array[Dictionary]=[]
var rivers: Dictionary={}
var river_jobs: Array[Dictionary]=[]
var lake_jobs: Array[Dictionary]=[]
var river_tiles: Dictionary={}
var recovery: Dictionary={}
var recovery_key:=""
var interest_key:=""
var hydro: Dictionary
var source_added:=0.0
var source_removed:=0.0
var maximum_usec:=0
var capped:=false
var turn:=0
var changed:=false
var elapsed:=0.0
var visits: Dictionary={}
func configure(terrain: FrontierTerrainField) -> void:
 field=terrain;original=FrontierTerrainField.new();original.configure(field.seed_value,[],field.span,field.traits)
 native=FrontierSurfaceDrainage.liquid(field.traits)
 hydro=JSON.parse_string(FileAccess.get_file_as_string("res://data/surface_hydrology.json"));ocean_level=float(hydro.sea_level)
func bind(state: Dictionary,terrain: FrontierTerrainField,edits: Array,centers: Array[Vector3],region: Dictionary={}) -> void:
 record=state;interests=centers
 if field!=terrain:
  field=terrain;cache.clear();faces.clear();rivers.clear();river_tiles.clear();river_jobs.clear();lake_jobs.clear();recovery_key=""
 if queue.is_empty():
  for k in record.cells:_wake(k)
 while edits_seen<edits.size():
  var edit: Dictionary=edits[edits_seen];edits_seen+=1
  var ep:=FrontierCrewWorld.vector(edit.center)
  edit_bounds.append(Vector4(ep.x,ep.y,ep.z,float(edit.radius)+5))
  var p:=cell(ep);var r:=ceili(float(edit.radius))+2
  seed_jobs.append({"min":p-Vector3i.ONE*r,"size":2*r+1,"cursor":0})
  # Geometry may open a previously settled bank. Revisit saved water without erasing it.
  cache.clear();faces.clear()
 recovery=region
 var new_recovery: String=str(region.get("center",Vector3.ZERO)) if not region.is_empty() and float(region.state.wet)>.02 else ""
 if not native and new_recovery!=recovery_key:
  recovery_key=new_recovery;rivers.clear();river_jobs.clear()
  if not recovery_key.is_empty():
   var best:=Vector3(0,-INF,0)
   for i in 16:
    var q: Vector3=region.center+Vector3(cos(i*TAU/16),0,sin(i*TAU/16))*float(region.radius)*.65
    q.y=original.height(q.x,q.z)
    if q.y>best.y and Vector2(q.x,q.z).length()>25:best=q
   river_jobs.append({"step":0,"at":best,"managed":true})
 var new_interest:=""
 for p in centers:new_interest+=str(Vector2i(floori(p.x/32),floori(p.z/32)))
 if new_interest!=interest_key:
  interest_key=new_interest;cache.clear();faces.clear()
  if river_tiles.size()>150 or rivers.size()>=int(config().maximum_native_columns):
   river_tiles.clear();river_jobs.clear();rivers.clear()
  for bound in edit_bounds:
   var p:=Vector3(bound.x,bound.y,bound.z)
   if not _near(p):continue
   var r:=ceili(bound.w)-3
   seed_jobs.append({"min":cell(p)-Vector3i.ONE*r,"size":2*r+1,"cursor":0})
 for p in centers:
  var tile:=Vector2i(floori(p.x/256),floori(p.z/256))
  if native:
   for ox in [0,-1,1]:
    var x:=tile.x+int(ox)
    for oz in [0,-1,1]:
     var z:=tile.y+int(oz)
     var k:="%d:%d"%[x,z]
     if river_tiles.has(k):continue
     river_tiles[k]=true
     for i in 2:river_jobs.append({"tile":Vector2i(x,z),"index":i,"step":-1,"at":Vector3.ZERO})
func _wake(k: String) -> void:
 if queued.has(k):return
 queued[k]=true;queue.append(k)
func _near(p: Vector3) -> bool:
 for center in interests:
  if center.distance_squared_to(p)<pow(float(config().active_radius),2):return true
 return false
func geometry(c: Vector3i) -> float:
 var k:=key(c)
 if cache.has(k):return cache[k]
 # Lowest connected air sample in this vertical cell; subcell rock remains a floor.
 var bottom:=1.0
 for i in range(7,-1,-1):
  var p:=Vector3(c)+Vector3(.5,(i+.5)/8.0,.5)
  if field.density(p)>=-.015:break
  bottom=float(i)/8.0
 cache[k]=bottom
 return bottom
func _pass(a: Vector3i,b: Vector3i) -> bool:
 var id:=key(a)+"/"+key(b)
 if faces.has(id):return faces[id]
 var offset:=Vector3(b-a);var p:=(Vector3(a)+Vector3(b))*.5+Vector3.ONE*.5
 if offset.y==0:p.y=maxf(a.y+geometry(a),b.y+geometry(b))+.07
 var ok:=field.density(p)<-.025
 # Check the path across the whole shared face, including narrow rock partitions.
 for f in [-.3,.3]:
  if field.density(p+offset*f)>=-.025:ok=false
 faces[id]=ok;return ok
func reservoir(c: Vector3i,bottom: float) -> float:
 var p:=Vector3(c)+Vector3(.5,0,.5);var base:=original.height(p.x,p.z)
 var level:=ocean_level if native and base<ocean_level else -INF
 var r: float=rivers.get("%d:%d"%[c.x,c.z],-INF)
 level=maxf(level,r)
 # A cave underneath a sea is NOT a reservoir: original soil must separate them.
 if level<=c.y+bottom or c.y+bottom<base-.08:return 0.0
 var capacity:=1.0-bottom
 return minf(capacity,maxf(0,level-c.y-bottom))+maxf(0,level-c.y-1)*float(config().compression)
func _seed(c: Vector3i) -> void:
 if not _near(Vector3(c)):return
 var bottom:=geometry(c)
 if bottom>=1:return
 var amount:=reservoir(c,bottom)
 if amount<=0:return
 var k:=key(c)
 if not record.cells.has(k):
  if record.cells.size()>=int(config().maximum_cells_per_planet):capped=true;return
  record.cells[k]=[amount,bottom];source_added+=amount;changed=true;_wake(k)
func _trace() -> void:
 if not lake_jobs.is_empty():
  var lake: Dictionary=lake_jobs[0];var radius:=ceili(float(hydro.lake_radius));var size:=radius*2+1;var n:=int(lake.cursor)
  var p: Vector3=lake.center+Vector3(n%size-radius,0,n/size as int-radius)
  var height_value:=original.height(p.x,p.z)
  for i in 7:
   var q: Vector3=lake.center.lerp(p,(i+1)/8.0)
   if original.height(q.x,q.z)>float(lake.level):height_value=INF;break
  if Vector2(p.x-lake.center.x,p.z-lake.center.z).length()<=radius and height_value<=float(lake.level):
   var c:=cell(Vector3(p.x,float(lake.level),p.z));_remember_river("%d:%d"%[c.x,c.z],float(lake.level))
   if _near(p):
    for bound in edit_bounds:
     if p.distance_squared_to(Vector3(bound.x,bound.y,bound.z))<bound.w*bound.w:_seed(c);break
  lake.cursor+=1
  if lake.cursor>=size*size:lake_jobs.pop_front()
  return
 if river_jobs.is_empty():return
 var job: Dictionary=river_jobs[0]
 if job.step<0:
  job.at=FrontierSurfaceDrainage.source(original,job.tile,job.index,hydro);job.step=0;return
 var at: Vector3=job.at
 var next:=FrontierSurfaceDrainage.advance(original,at,hydro)
 if next==at:
  lake_jobs.append({"center":at,"level":at.y+float(hydro.river_depth),"cursor":0});river_jobs.pop_front();return
 if job.step>=int(hydro.maximum_steps) or at.y<ocean_level or Vector2(at.x,at.z).length()<24:river_jobs.pop_front();return
 if job.get("managed",false) and (recovery.is_empty() or FrontierSurfaceRecovery.weight(next,recovery.center,recovery.radius)<.12):river_jobs.pop_front();return
 var broken:=field.density(next-Vector3.UP*.4)<0
 for n in 9:
  var p:=at.lerp(next,n/8.0);p.y=original.height(p.x,p.z)+float(hydro.river_depth)
  var c:=cell(p);var k:="%d:%d"%[c.x,c.z]
  _remember_river(k,p.y)
  var lateral:=Vector3(-(next-at).z,0,(next-at).x).normalized()
  for side in [-1,1]:
   for width in [0.5,1.0,1.5,2.0]:
    var q:=p+lateral*float(side)*float(width)
    if original.height(q.x,q.z)>p.y-.02:break
    _remember_river("%d:%d"%[floori(q.x),floori(q.z)],p.y)
  # Seed only actual excavations; untouched rivers keep their inexpensive analytic surface.
  if _near(p):
   for bound in edit_bounds:
    if p.distance_squared_to(Vector3(bound.x,bound.y,bound.z))<bound.w*bound.w:_seed(c);break
 if broken:river_jobs.pop_front();return
 job.at=next;job.step+=1
func _move(a: String,b: String,amount: float,bottom: float) -> void:
 amount=minf(amount,float(record.cells[a][0]))
 if amount<=0:return
 if not record.cells.has(b):
  if record.cells.size()>=int(config().maximum_cells_per_planet):capped=true;return
  record.cells[b]=[0.0,bottom];_wake(b)
 amount=minf(amount,float(config().maximum_mass)-float(record.cells[b][0]))
 record.cells[a][0]-=amount;record.cells[b][0]+=amount;changed=true
func _cell_step(k: String) -> void:
 if not record.cells.has(k):return
 var c:=point(k)
 if not _near(Vector3(c)):return
 var bottom:=geometry(c)
 if record.cells[k][1]!=bottom:changed=true
 record.cells[k][1]=bottom
 if bottom>=1:return
 var supplied:=reservoir(c,bottom)
 if supplied>0:
  var change:=supplied-float(record.cells[k][0])
  if absf(change)>.000001:changed=true
  source_added+=maxf(0,change);source_removed+=maxf(0,-change);record.cells[k][0]=supplied
 var compression:=float(config().compression)
 var directions: Array[Vector3i]=[Vector3i.DOWN]
 var sides: Array[Vector3i]=[Vector3i.LEFT,Vector3i.FORWARD,Vector3i.RIGHT,Vector3i.BACK]
 for i in 4:directions.append(sides[(i+turn)%4])
 directions.append(Vector3i.UP)
 for direction in directions:
  var b:=c+direction;var bk:=key(b);var floor_b:=geometry(b)
  if floor_b>=1 or not _pass(c,b):continue
  var mass:=float(record.cells[k][0]);var other: float=record.cells.get(bk,[0.0,floor_b])[0]
  var capacity:=1.0-floor_b;var flow:=0.0
  if direction.y<0:
   var total:=mass+other
   var stable:=minf(total,capacity)
   if total>capacity:stable=(capacity*capacity+total*compression)/(capacity+compression) if total<2*capacity+compression else (total+compression)*.5
   flow=stable-other
  elif direction.y>0:
   var capacity_a:=1.0-bottom
   var total:=mass+other
   var stable:=minf(total,capacity_a)
   if total>capacity_a:stable=(capacity_a*capacity_a+total*compression)/(capacity_a+compression) if total<2*capacity_a+compression else (total+compression)*.5
   flow=mass-stable
  else:flow=(mass+bottom-other-floor_b)*.25
  flow=minf(maxf(flow,0),float(config().flow_per_step))
  if flow>float(config().minimum_mass):_move(k,bk,flow,floor_b)
 # Retain tiny residuals; only exactly empty cells release their storage slot.
 if supplied<=0 and float(record.cells[k][0])==0.0:record.cells.erase(k)
func step(delta: float=1.0/60.0) -> void:
 elapsed+=delta
 var start:=Time.get_ticks_usec();turn+=1;changed=false
 for i in int(config().seed_steps_per_frame):
  if Time.get_ticks_usec()-start>=int(config().budget_usec):break
  if i%2==0:_trace()
  if seed_jobs.is_empty():continue
  var job: Dictionary=seed_jobs[0];var n:=int(job.cursor);var size:=int(job.size)
  _seed(job.min+Vector3i(n%size,(n/size as int)%size,n/(size*size) as int));job.cursor+=1
  if job.cursor>=size*size*size:seed_jobs.pop_front()
 for i in mini(int(config().cells_per_frame),queue.size()):
  if queue.is_empty() or Time.get_ticks_usec()-start>=int(config().budget_usec):break
  if cursor>=queue.size():cursor=0
  var k:=queue[cursor]
  if elapsed-float(visits.get(k,-1))>=float(config().tick_seconds):
   visits[k]=elapsed;_cell_step(k)
  if not record.cells.has(k):queued.erase(k);visits.erase(k);queue.remove_at(cursor)
  else:cursor+=1
 if changed:record.serial+=1
 maximum_usec=maxi(maximum_usec,Time.get_ticks_usec()-start)
func sample(p: Vector3) -> float:
 var result:=depth(record,p)
 var base:=original.height(p.x,p.z)
 if native and base<ocean_level and p.y>=base:result=maxf(result,ocean_level-p.y)
 var level: float=rivers.get("%d:%d"%[floori(p.x),floori(p.z)],-INF)
 if p.y>=base-.1 and field.density(Vector3(p.x,base-.35,p.z))>=0:result=maxf(result,level-p.y)
 return maxf(0,result)

# Analytic channels are a bounded transient replica, never additional fluid mass in the save.
func columns_packet(p: Vector3) -> Dictionary:
 var columns: Dictionary={}
 var extent:=24
 for x in range(floori(p.x)-extent,floori(p.x)+extent+1):
  for z in range(floori(p.z)-extent,floori(p.z)+extent+1):
   var k:="%d:%d"%[x,z]
   if rivers.has(k):columns[k]=rivers[k]
 return columns

func intersect(start: Vector3,direction: Vector3,distance: float) -> Dictionary:
 if direction.length_squared()<.9 or field.density(start)>0:return {}
 var previous:=start
 var wet:=sample(start)>.002
 for i in range(1,ceili(distance/.08)+1):
  var p:=start+direction*minf(i*.08,distance)
  # Solid terrain has priority, including the floor under very shallow channels.
  if field.density(p)>0:return {}
  var next_wet:=sample(p)>.002
  if next_wet!=wet:
   var a:=previous;var b:=p
   for n in 8:
    var middle:=(a+b)*.5
    if (sample(middle)>.002)==wet:a=middle
    else:b=middle
   var at:=(a+b)*.5
   return {"position":[at.x,at.y,at.z],"distance":start.distance_to(at),"entering":not wet}
  previous=p
 return {}

func _remember_river(k: String,level: float) -> void:
 if rivers.has(k) or rivers.size()<int(config().maximum_native_columns):rivers[k]=level
