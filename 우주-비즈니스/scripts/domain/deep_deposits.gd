extends RefCounted
static func deposits(body:Dictionary,field:FrontierTerrainField,owner:Vector2i)->Array:
 if field.caves==null:return []
 var span:float=field.caves.rules.region_size;var system:=field.caves.system_at(owner.x*span,owner.y*span)
 var deep:Dictionary=system.get("deep",{})
 if deep.is_empty():return []
 var profile:Dictionary=body.mineral_profile;var result:Array=[]
 for slot in 3:
  var id: String="deep1:%d:%d:%d"%[owner.x,owner.y,slot];var seed_value:=FrontierUniverse.derive(int(body.streams.resource),id)
  var pool:Array=profile.primary+profile.secondary
  var resource:String=pool[seed_value%pool.size()]
  if slot==0 and seed_value%100<int(deep.rules.gem_chance):resource=profile.gems[seed_value%profile.gems.size()]
  elif slot==2 and not profile.exotic.is_empty() and seed_value%3==0:resource=profile.exotic
  var at:Vector3=deep.floor+[Vector3(-4,.05,-3),Vector3(4,.05,-3),Vector3(0,.05,5)][slot]
  if maxf(absf(at.x),absf(at.z))>preload("res://scripts/domain/surface_content_bounds.gd").extent(body):continue
  var top:float=at.y+4;var bottom:float=at.y-2
  if field.density(Vector3(at.x,top,at.z))>=0 or field.density(Vector3(at.x,bottom,at.z))<=0:continue
  for iteration in 12:
   var mid:float=(top+bottom)*.5
   if field.density(Vector3(at.x,mid,at.z))>0:bottom=mid
   else:top=mid
  at.y=(top+bottom)*.5+.05
  var base:int=profile.rules.gem_capacity if FrontierMinerals.entry(resource).category=="gem" else int(profile.rules.base_capacity)+seed_value%int(profile.rules.capacity_spread)
  if FrontierMinerals.entry(resource).category!="gem" and int(profile.rules.get("version",1))>=3:
   base+=maxi(0,int(body.planet_tier)-1)*int(profile.rules.capacity_per_tier)+mini(int(profile.rules.capacity_distance_cap),floori(Vector2(at.x,at.z).length()/1000.0)*int(profile.rules.capacity_per_km))
  var amount:=floori(base*float(deep.rules.ore_capacity_factor))
  result.append({"id":id,"resource":resource,"required_tier":int(profile.rules.get("resource_tiers",FrontierMineralWorld.rules().resource_tiers).get(resource,1)),"capacity":amount,"position":FrontierExpeditionBusiness.array(at),"underground":true,"quality":3})
 return result
static func region(body:Dictionary,field:FrontierTerrainField,x:int,z:int)->Array:
 if field.caves==null or not field.caves.rules.has("deep"):return []
 var tile:float=body.mineral_profile.rules.tile_size
 var owner:=field.caves.region_at((x+.5)*tile,(z+.5)*tile)
 var result:Array=[]
 for row in deposits(body,field,owner):
  if floori(row.position[0]/tile)==x and floori(row.position[2]/tile)==z:result.append(row)
 return result
static func find(body:Dictionary,id:String)->Dictionary:
 var parts:=id.split(":")
 if parts.size()!=4 or parts[0]!="deep1":return {}
 for i in range(1,4):
  if not parts[i].is_valid_int() or str(int(parts[i]))!=parts[i]:return {}
 if int(parts[3]) not in [0,1,2]:return {}
 var limit:=ceili(preload("res://scripts/domain/surface_content_bounds.gd").extent(body)/float(body.get("terrain_traits",{}).get("underground",{}).get("region_size",768)))+1
 if absi(int(parts[1]))>limit or absi(int(parts[2]))>limit:return {}
 var field:=FrontierSurfaceRegions.field(body)
 for row in deposits(body,field,Vector2i(int(parts[1]),int(parts[2]))):
  if row.id==id:return row
 return {}
