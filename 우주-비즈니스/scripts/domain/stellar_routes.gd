class_name FrontierStellarRoutes
extends RefCounted
static var key: String=""
static var points:=PackedVector2Array()
static var cells: Dictionary={}
static var built:=0
static var revision:=0
static var nearby_cache: Dictionary={}
const PAGE_SIZE:=1024
const CACHE_VERSION:=1
static var ready:=PackedByteArray()
static var insertion_order:=PackedInt32Array()
static var page_order: Array[int]=[]
static var finished: Dictionary={}
static var active_page: int=-1
static var page_offset:=0
static var page_values:=PackedVector2Array()
static var page_loaded:=false
static var focus_band: int=-1
static var generated:=0
static var restored:=0
static var cache_root: String=""
static func identity(manifest: Dictionary) -> String:
 return FrontierUniverse.fingerprint({"version":CACHE_VERSION,"id":manifest.id,"seed":manifest.seed,"count":manifest.settings.planet_count,"per_system":manifest.settings.planets_per_system,"outer":manifest.settings.outer_radius,"inner":manifest.settings.inner_radius,"bands":manifest.settings.tier_weights.size()})
static func reset() -> void:
 key="";built=0;points.clear();ready.clear();insertion_order.clear();cells.clear();nearby_cache.clear();page_order.clear();finished.clear();active_page=-1;page_offset=0;page_values.clear();focus_band=-1;generated=0;restored=0
static func build(manifest: Dictionary,current_system: int=0,budget_usec: int=1500) -> void:
 if manifest.is_empty():return
 # Avoid hashing the manifest on every frame. Identity changes on world replacement/settings change.
 var session_key:=str([manifest.id,manifest.seed,manifest.settings.planet_count,manifest.settings.planets_per_system,manifest.settings.outer_radius,manifest.settings.inner_radius,manifest.settings.tier_weights.size()])
 if key!=session_key:
  reset();key=session_key
  points.resize(int(manifest.settings.planet_count)/int(manifest.settings.planets_per_system));ready.resize(points.size());ready.fill(0)
  var folder: String="user://navigation_cache"
  for arg in OS.get_cmdline_user_args():
   if arg.begins_with("--crew-folder="):folder=arg.trim_prefix("--crew-folder=")+"/navigation_cache"
  cache_root=folder+"/"+identity(manifest)
  DirAccess.make_dir_recursive_absolute(cache_root)
 if built>=points.size():return
 var bands: int=manifest.settings.tier_weights.size()
 var band:=clampi(current_system/maxi(1,points.size()/bands),0,bands-1)
 if band!=focus_band:
  focus_band=band;page_order.clear()
  for page in ceili(float(points.size())/PAGE_SIZE):
   if not finished.has(page) and page!=active_page:page_order.append(page)
  # IDs are radially banded: prioritize the current radial band, then adjacent bands.
  page_order.sort_custom(func(a,b):
   var da:=absi(mini(a*PAGE_SIZE/(points.size()/bands),bands-1)-band)
   var db:=absi(mini(b*PAGE_SIZE/(points.size()/bands),bands-1)-band)
   return da<db if da!=db else a<b)
 var deadline:=Time.get_ticks_usec()+maxi(0,budget_usec)
 var changed:=false
 while built<points.size() and Time.get_ticks_usec()<deadline:
  if active_page<0:
   if page_order.is_empty():break
   active_page=page_order.pop_front();page_offset=0;page_values=_read_page(active_page)
   page_loaded=not page_values.is_empty()
   if not page_loaded:page_values.resize(mini(PAGE_SIZE,points.size()-active_page*PAGE_SIZE))
  var index:=active_page*PAGE_SIZE+page_offset
  var point: Vector2=page_values[page_offset] if page_loaded else FrontierUniverse.map_position(manifest,index)
  if page_loaded:restored+=1
  else:page_values[page_offset]=point;generated+=1
  points[index]=point;ready[index]=1;insertion_order.append(index)
  var cell:=Vector2i((point/8.0).floor())
  if not cells.has(cell):cells[cell]=[]
  cells[cell].append(index);built+=1;page_offset+=1;changed=true
  if page_offset==page_values.size():
   if not page_loaded:_write_page(active_page,page_values)
   finished[active_page]=true;active_page=-1
   break
 if changed:revision+=1;nearby_cache.clear()
static func _read_page(page: int) -> PackedVector2Array:
 var path:=cache_root+"/%d.bin"%page
 if not FileAccess.file_exists(path):return PackedVector2Array()
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null or file.get_length()>PAGE_SIZE*16+1024:return PackedVector2Array()
 var value: Variant=file.get_var(false)
 if not value is Dictionary or value.get("version")!=CACHE_VERSION or not value.get("points") is PackedVector2Array:return PackedVector2Array()
 var result: PackedVector2Array=value.points
 if result.size()!=mini(PAGE_SIZE,points.size()-page*PAGE_SIZE) or value.get("checksum")!=result.to_byte_array().hex_encode().sha256_text():return PackedVector2Array()
 for point in result:
  if not is_finite(point.x) or not is_finite(point.y):return PackedVector2Array()
 return result
static func _write_page(page: int,value: PackedVector2Array) -> void:
 var path:=cache_root+"/%d.bin"%page
 var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null:return
 file.store_var({"version":CACHE_VERSION,"points":value,"checksum":value.to_byte_array().hex_encode().sha256_text()});file.flush();file.close()
 DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))
static func has_point(index: int) -> bool:return index>=0 and index<ready.size() and ready[index]!=0
static func nearby(manifest: Dictionary,index: int,radius: float) -> Array:
 var cache_key:=str(index)+":"+str(radius)
 if nearby_cache.has(cache_key):return nearby_cache[cache_key]
 var center:=FrontierUniverse.map_position(manifest,index)
 var low:=Vector2i(((center-Vector2.ONE*radius)/8.0).floor())
 var high:=Vector2i(((center+Vector2.ONE*radius)/8.0).floor())
 var result: Array=[]
 for y in range(low.y,high.y+1):
  for x in range(low.x,high.x+1):
   for candidate in cells.get(Vector2i(x,y),[]):
    if candidate==index:continue
    var offset:=points[candidate]-center
    if offset.length()<=radius+.001:result.append({"index":candidate,"distance":offset.length(),"offset":offset})
 result.sort_custom(func(a,b):return a.distance<b.distance)
 nearby_cache[cache_key]=result;return result
static func directional(manifest: Dictionary,index: int,radius: float) -> Array:
 var sectors: Dictionary={}
 for item in nearby(manifest,index,radius):
  var sector:=posmod(floori((item.offset.angle()+PI)*8.0/TAU),8)
  if not sectors.has(sector):sectors[sector]=item
 return sectors.values()
