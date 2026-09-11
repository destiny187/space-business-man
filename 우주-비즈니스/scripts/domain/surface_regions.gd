class_name FrontierSurfaceRegions
extends RefCounted
## Immutable surface-only addressing. Underground continues to use ore1 slots unchanged.
static var _config: Dictionary={}
static var _zones: Dictionary={}
static var _fields: Dictionary={}
static var _clusters: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/regional_terraforming.json"))
 return _config
static func enabled(body: Dictionary) -> bool:return body.has("regional_rules")
static func field(body: Dictionary) -> FrontierTerrainField:
 var key: String=str(body.id)
 if _fields.has(key):return _fields[key]
 var f:=FrontierTerrainField.new();f.configure(int(body.streams.terrain),[],24.0,body.get("terrain_traits",{}))
 if _fields.size()>8:_fields.clear()
 _fields[key]=f;return f
static func sample(body: Dictionary,f: FrontierTerrainField,p: Vector2) -> Dictionary:
 var span: float=body.regional_rules.region_span
 var tile:=Vector2i(floori(p.x/span),floori(p.y/span))
 var seed_value:=FrontierUniverse.derive(int(body.streams.resource),"surface-region:%d:%d"%[tile.x,tile.y])
 var height:=f.height(p.x,p.y)
 var slope:=absf(f.height(p.x+8,p.y)-height)+absf(f.height(p.x,p.y+8)-height)
 var native: Dictionary=body.get("traits",{})
 var geology: String="rock" if slope>4 else ("basin" if height<f.height(tile.x*span+span*.5,tile.y*span+span*.5) else "ridge")
 if body.kind=="glacial" and float(native.get("water",0))>0:geology="ice"
 if body.kind=="sulfur":geology="thermal"
 var preferences: Array={"rock":["iron","copper","nickel","titanium"],"basin":["phosphate","aluminum","lithium"],"ridge":["silicon","rare_earth","copper"],"ice":["ice","lithium","nickel"],"thermal":["sulfur","copper","iron"]}[geology]
 var pool: Array=body.mineral_profile.primary+body.mineral_profile.secondary
 var choices: Array=[]
 for key in preferences:
  if key in pool:choices.append(key)
 if choices.is_empty():choices=pool
 elif seed_value%5==0:choices=pool
 return {"id":"surface:%d:%d"%[tile.x,tile.y],"geology":geology,"height":height,"resource":choices[seed_value%choices.size()],"tile":tile}
static func cluster(body: Dictionary,x: int,z: int) -> Dictionary:
 var cache_key: String=body.id+":%d:%d"%[x,z]
 if _clusters.has(cache_key):return _clusters[cache_key]
 var f:=field(body);var span: float=body.regional_rules.region_span
 var seed_value:=FrontierUniverse.derive(int(body.streams.resource),"cluster:%d:%d"%[x,z])
 var center:=Vector2((x+.25+float(seed_value%500)/1000)*span,(z+.25+float((seed_value/500)%500)/1000)*span)
 var info:=sample(body,f,center);info.center=center
 if _clusters.size()>2048:_clusters.clear()
 _clusters[cache_key]=info;return info
static func surface(body: Dictionary,x: int,z: int) -> Array:
 var rows: Array=[];var rules: Dictionary=body.mineral_profile.rules
 var size: float=rules.tile_size;var span: float=body.regional_rules.region_span
 var f:=field(body)
 for slot in int(rules.surface_slots)*4:
  var id: String="surf1:%d:%d:%d"%[x,z,slot]
  var seed_value:=FrontierUniverse.derive(int(body.streams.resource),id)
  var at:=Vector2(x*size+(slot%8+.25+float(seed_value%500)/1000)*size/8,z*size+(slot/8+.25+float(FrontierUniverse.derive(seed_value,"z")%500)/1000)*size/6)
  if maxf(absf(at.x),absf(at.y))>float(rules.region_half_extent):continue
  if body.has("ground_rules") and at.length()<float(body.ground_rules.near_resource_radius):continue
  var tile:=Vector2i(floori(at.x/span),floori(at.y/span));var group:=cluster(body,tile.x,tile.y)
  var relative: Vector2=(at-group.center)/Vector2(span*.32,span*.20)
  var clustered: bool=relative.length()<.92+float(seed_value%160)/1000
  if not clustered and slot>=maxi(1,int(rules.surface_slots)/4):continue
  if maxf(absf(at.x),absf(at.y))>float(rules.region_half_extent):continue
  if body.has("ground_rules") and at.length()<float(body.ground_rules.near_resource_radius):continue
  var info:=sample(body,f,at)
  var resource: String=group.resource if clustered else (body.mineral_profile.primary+body.mineral_profile.secondary)[seed_value%(body.mineral_profile.primary.size()+body.mineral_profile.secondary.size())]
  if body.has("ground_rules") and int(body.planet_tier)==2 and resource in ["silicon","phosphate"] and at.length()<float(body.ground_rules.expedition.radius):continue
  var capacity:=int(rules.base_capacity)+seed_value%int(rules.capacity_spread)+maxi(0,int(body.planet_tier)-1)*int(rules.capacity_per_tier)
  rows.append({"id":id,"resource":resource,"required_tier":FrontierMineralWorld.tier(resource),"capacity":capacity,"position":[at.x,0,at.y],"underground":false,"quality":1+seed_value%int(rules.quality_levels),"geology":info.geology})
 return rows
static func find(body: Dictionary,id: String) -> Dictionary:
 var parts:=id.split(":")
 if parts.size()!=4 or not parts[1].is_valid_int() or not parts[2].is_valid_int():return {}
 for row in surface(body,int(parts[1]),int(parts[2])):
  if row.id==id:return row
 return {}
static func zones(body: Dictionary) -> Array:
 if not enabled(body) or not body.regional_rules.tiers.has(str(int(body.planet_tier))):return []
 var key: String=body.id+":"+str(body.regional_rules.version)
 if _zones.has(key):return _zones[key]
 var cfg: Dictionary=body.regional_rules;var tier: Dictionary=cfg.tiers[str(int(body.planet_tier))]
 var f:=field(body);var result: Array=[]
 for i in int(tier.regions):
  var best:=Vector3(-4,f.height(-4,4),4)
  if i>0:
   var angle:=float(FrontierUniverse.derive(int(body.streams.terrain),"restore-direction")%10000)/10000*TAU+float(i-1)*TAU/float(int(tier.regions)-1)
   if int(tier.regions)==3:angle=float(FrontierUniverse.derive(int(body.streams.terrain),"restore-direction")%10000)/10000*TAU+float(i-1)*PI*.82
   var score:=INF
   for n in 80:
    var a:=angle+float(n%9-4)*.075;var distance:=float(tier.distance)+float(n/9)*14
    var at:=Vector2(cos(a),sin(a))*distance
    var y:=f.height(at.x,at.y);var variation:=0.0
    for offset in [Vector2(12,0),Vector2(-12,0),Vector2(0,12),Vector2(0,-12)]:variation+=absf(f.height(at.x+offset.x,at.y+offset.y)-y)
    if variation<score:score=variation;best=Vector3(at.x,y,at.y)
  var names: Array=["착륙 정착지","급수 복원지","토양 복원지"];var roles: Array=["settlement","water","soil"]
  if FrontierTerraformTier3.enabled(body):
   var profile: Dictionary=FrontierTerraformTier3.rules_for(body).profiles[FrontierTerraformTier3.profile_id(body)];names=profile.names;roles=profile.roles
  result.append({"id":"region:%d"%i,"name":names[i],"center":[best.x,best.y,best.z],"radius":float(cfg.zone_radius),"role":roles[i]})
 if _zones.size()>64:_zones.clear()
 _zones[key]=result;return result
