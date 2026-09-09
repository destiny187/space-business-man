class_name FrontierFacilityFlooding
extends RefCounted
## Host rule; exported Blender model envelopes avoid loading meshes in simulation ticks.
const STATUS: String="완전 침수 · 사용 불가"
static var _config: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/facility_water_bounds.json"))
 return _config
static func bounds(row: Dictionary) -> AABB:
 var tiers: Dictionary=config().bounds.get(row.get("type",""),{})
 var box: Dictionary=tiers.get(str(int(row.get("tier",1))),tiers.get("1",{}))
 if box.is_empty():return AABB()
 var low:=FrontierCrewWorld.vector(box.min);var high:=FrontierCrewWorld.vector(box.max)
 return AABB(low,high-low)
static func enclosed(row: Dictionary,wet: Callable) -> bool:
 var box:=bounds(row)
 if box.size==Vector3.ZERO:return false
 var origin:=FrontierCrewWorld.vector(row.position)
 var rotation:=Basis(Vector3.UP,float(row.get("yaw",0)))
 var margin:=float(config().submerge_margin)
 # All roof corners/edge centres must be below water, not only the object's origin.
 for x in [box.position.x,box.get_center().x,box.end.x]:
  for z in [box.position.z,box.get_center().z,box.end.z]:
   if not wet.call(origin+rotation*Vector3(x,box.end.y+margin,z)):return false
 # A disconnected sheet above a dry facility is not complete immersion.
 var bottom:=maxf(.1,box.position.y+.1)
 var y:=bottom
 while y<box.end.y:
  if not wet.call(origin+rotation*Vector3(box.get_center().x,y,box.get_center().z)):return false
  y+=.5
 return true
static func wet_at(p: Vector3,record: Dictionary,field: FrontierTerrainField,native: bool,sea: float) -> bool:
 var c:=FrontierSurfaceWater.cell(p)
 var row: Array=record.get("cells",{}).get(FrontierSurfaceWater.key(c),[])
 if not row.is_empty():
  var bottom:=float(c.y)+float(row[1]);var top:=float(c.y)+minf(1,float(row[0])+float(row[1]))
  if p.y>=bottom and p.y<top:return true
 # Ocean is a source only above its original bed; sealed caves below land remain dry.
 return native and p.y<sea and p.y>=field.height(p.x,p.z)
static func submerged(world: Dictionary,row: Dictionary) -> bool:
 var record: Dictionary=world.get("surface_water",{}).get(world.location,{})
 var field:=FrontierCrewSurface.field(world)
 var native:=FrontierSurfaceDrainage.liquid(field.traits)
 if not native and record.get("cells",{}).is_empty():return false
 return enclosed(row,func(p: Vector3):return wet_at(p,record,field,native,-4.0))
static func refresh(world: Dictionary,row: Dictionary) -> bool:
 var flooded:=submerged(world,row)
 row.submerged=flooded
 if flooded:row.active=false;row.working=false;row.status=STATUS
 return flooded
static func guard(world: Dictionary,actor: String,kind: String,args: Dictionary) -> String:
 if kind=="business_demolish":return ""
 var local:=FrontierShuttles.context(world,actor)
 if not FrontierCrewSurface.landed(local):return ""
 var id:=str(args.get("building_id",args.get("facility_id",args.get("factory_id",args.get("access_facility_id","")))))
 if id.is_empty():return ""
 var row: Dictionary=FrontierExpeditionBusiness.site(local).get("buildings",{}).get(id,{})
 return STATUS+" · 수위가 내려간 뒤 이용하세요." if not row.is_empty() and submerged(local,row) else ""

static func refresh_base(world: Dictionary,site: Dictionary) -> void:
 if site.is_empty():return
 site.base_submerged=submerged(world,{"type":"storage","position":site.center})
