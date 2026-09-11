class_name FrontierSpaceStation
extends RefCounted
const Economy=preload("res://scripts/domain/station_economy.gd")
static var _config: Dictionary={}
static var stations: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/space_stations.json"))
 return _config
static func definition(m: Dictionary,index: int,excluded: int=-1,elapsed: float=0.0,station_id: String="") -> Dictionary:
 if index==excluded:return {}
 if index==0:return FrontierOrbitalPorts.definition(m,"solar_mars_port" if station_id.is_empty() else station_id,elapsed)
 if not station_id.is_empty() and station_id!=str(index):return {}
 var key: String=m.id+":"+str(index)
 if stations.has(key):return stations[key]
 var result: Dictionary={}
 var seed_value:=FrontierUniverse.derive(int(m.seed),"station-v1:"+str(index))
 # Exclude the tutorial destination regardless of the order in which worlds are queried.
 if index!=0 and index!=FrontierUniverse.system_index(m,FrontierCrewNavigation.first_destination(m)) and seed_value%100<int(config().appearance_percent):
  var angle:=float(seed_value%10000)/10000.0*TAU
  var point:=Vector3(cos(angle)*float(config().orbit_radius),float(config().altitude),sin(angle)*float(config().orbit_radius))
  result={"id":str(index),"name":"WAYFARER %03d"%(seed_value%1000),"position":[point.x,point.y,point.z],"seed":seed_value}
 stations[key]=result
 return result
static func all(m: Dictionary,index: int,excluded: int=-1,elapsed: float=0.0) -> Array:
 if index==excluded:return []
 if index==0:return FrontierOrbitalPorts.all(m,elapsed)
 var station:=definition(m,index,excluded,elapsed)
 return [] if station.is_empty() else [station]
static func current(m: Dictionary,nav: Dictionary,station_id: String="") -> Dictionary:
 if station_id.is_empty() and (nav.get("station_target",false) or not str(nav.get("station_docked","")).is_empty()):station_id=str(nav.get("station_id",nav.get("station_docked","")))
 if not station_id.is_empty():return definition(m,int(nav.system),int(nav.get("first_stellar_system",-1)),float(nav.orbit_time),station_id)
 var best: Dictionary={};var distance:=INF
 for station in all(m,int(nav.system),int(nav.get("first_stellar_system",-1)),float(nav.orbit_time)):
  var gap:=FrontierCrewWorld.vector(nav.position).distance_squared_to(FrontierCrewWorld.vector(station.position))
  if gap<distance:best=station;distance=gap
 return best
static func market(m: Dictionary,index: int,station_id: String="") -> Dictionary:
 var station:=definition(m,index,-1,0.0,station_id)
 if station.is_empty():return {}
 if station.get("fixed_port",false):return FrontierOrbitalPorts.market(station)
 var stock: Dictionary={};var prices: Dictionary={}
 for id in config().goods:
  var row: Dictionary=config().goods[id]
  var roll:=FrontierUniverse.derive(int(station.seed),id)
  # Three staples plus a random selection of other supplies.
  if id not in ["iron","copper","stone"] and roll%3==0:continue
  stock[id]=int(row.stock)*(75+roll%51)/100
  prices[id]=maxi(1,roundi(float(row.price)*float(90+roll%21)/100.0))
 var hull: String="swift" if int(station.seed)%2==0 else "mule"
 stock["hull:"+hull]=1;prices["hull:"+hull]=int(config().hulls[hull].price)
 return {"stock":stock,"prices":prices}
static func snapshot(world: Dictionary) -> Dictionary:
 var index:=int(world.crew.navigation.system)
 var station:=current(world.manifest,world.crew.navigation).duplicate(true)
 if station.is_empty():return {}
 var offers:=Economy.project(world,station,market(world.manifest,index,station.id))
 station.stock=offers.stock
 for key in ["demand","base_stock","market_epoch","cycle_seconds","refresh_seconds"]:station[key]=offers[key]
 station.prices=offers.prices
 station.sale_ratio=offers.get("sale_ratio",config().sale_ratio)
 station.capacities=offers.get("capacities",{})
 station.services={"goods":true,"ships":not station.get("fixed_port",false),"blueprints":not station.get("fixed_port",false),"owned":true}
 if station.get("fixed_port",false):station.blueprints=[]
 station.credits=int(world.get("business",{}).get("credits",FrontierExpeditionBusiness.config().starting_credits))
 return station
static func hull(vessel: Dictionary) -> Dictionary:return config().hulls.get(vessel.get("hull","kestrel"),config().hulls.kestrel)
static func available(world: Dictionary,station: Dictionary={}) -> bool:
 if FrontierCrewSurface.landed(world) or world.crew.navigation.mode!="idle" or absf(float(world.crew.navigation.speed))>5:return false
 if station.is_empty():station=current(world.manifest,world.crew.navigation)
 return not station.is_empty() and FrontierCrewWorld.vector(world.crew.navigation.position).distance_to(FrontierCrewWorld.vector(station.position))<=float(config().trade_distance)
static func apply(world: Dictionary,actor: String,action: String,args: Dictionary,active: Dictionary) -> String:
 var nav: Dictionary=world.crew.navigation
 var station:=current(world.manifest,nav,str(args.get("station","")))
 if station.is_empty() or FrontierCrewSurface.landed(world):return "이 항성계에는 교역 가능한 정거장이 없습니다."
 if action=="station_approach":
  if actor!=world.crew.pilot_id or nav.mode!="idle":return "대기 중인 조종사만 정거장 접근을 시작할 수 있습니다."
  for id in active.values():
   if not world.crew.members[id].aboard or not world.crew.members[id].ready:return "승무원 모두 승선·준비한 뒤 접근하세요."
  nav.station_id=station.id;nav.erase("station_docked");nav.station_target=true;nav.mode="approach";nav.manual=false;nav.boosting=false
  return ""
 if actor!=world.crew.owner_id:return "공동 자금 거래와 선체 교체는 호스트가 확정합니다."
 if not available(world,station):return "정거장 가까이 접근한 뒤 정지하세요."
 for id in active.values():
  if not world.crew.members[id].aboard:return "승무원이 모두 승선한 상태에서 거래하세요."
 if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
 if not world.business.bags.has(actor):world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
 if not world.has("vessel"):world.vessel=FrontierVesselRefit.create(int(world.manifest.seed),world.crew.world_id)
 var vessel: Dictionary=world.vessel
 if not vessel.has("hulls"):vessel.hulls=["kestrel"];vessel.hull="kestrel"
 var offers:=Economy.project(world,station,market(world.manifest,int(nav.system),station.id))
 var stock: Dictionary=offers.stock
 var id: String=str(args.get("item",""))
 var amount: Variant=args.get("amount",1)
 if not FrontierExpeditionBusiness.integer(amount,1,1000):return "거래 수량을 확인하세요."
 var count:=int(amount)
 if station.get("fixed_port",false) and action not in ["station_buy","station_sell","station_equip"]:return "이 물류항은 기초 물자만 거래합니다."
 match action:
  "station_equip":
   if id not in vessel.hulls:return "먼저 구매한 선체를 선택하세요."
   if id==vessel.hull:return "현재 사용 중인 선체입니다."
   vessel.hull=id
   var error:=FrontierVesselRefit.constraints(world)
   if not error.is_empty():return error
  "station_buy", "station_sell":
   if not offers.prices.has(id):return "이 정거장에서 취급하지 않는 상품입니다."
   if not id.begins_with("hull:") and args.has("quote") and args.quote!=offers.market_epoch:return "시세가 갱신되었습니다. 새 가격을 확인한 뒤 다시 거래하세요."
   var price:=int(offers.prices[id])
   if id.begins_with("hull:"):
    var chosen:=id.trim_prefix("hull:")
    if action!="station_buy" or count!=1:return "선체는 한 척씩 구매하며 기존 선체는 보관합니다."
    if chosen in vessel.hulls:return "이미 보유한 선체입니다."
    if int(stock[id])<1 or int(world.business.credits)<price:return "판매 선체 재고 또는 공동 자금이 부족합니다."
    world.business.credits-=price;stock[id]-=1;vessel.hulls.append(chosen)
   else:
    var bag: Dictionary=world.business.bags[actor]
    if action=="station_buy":
     if int(stock[id])<count or int(world.business.credits)<price*count:return "정거장 재고 또는 공동 자금이 부족합니다."
     if not FrontierItemInventory.fits(world,actor,{id:count}):return "아이템창에 빈 공간이 부족합니다."
     world.business.credits-=price*count;stock[id]-=count;bag[id]=int(bag.get(id,0))+count
    else:
     if int(bag.get(id,0))<count:return "판매할 개인 화물이 부족합니다."
     if int(stock[id])+count>int(offers.get("capacities",{}).get(id,config().max_stock)):return "정거장이 해당 물품을 더 매입할 수 없습니다."
     bag[id]-=count;stock[id]+=count;world.business.credits+=maxi(1,floori(price*float(offers.get("sale_ratio",config().sale_ratio))))*count
  _:return "지원하지 않는 정거장 거래입니다."
 Economy.commit(world,station.id,offers)
 if station.get("fixed_port",false):
  nav.station_id=station.id;nav.station_docked=station.id;identify(world,station)
 for member in world.crew.members.values():member.ready=false
 return ""
static func step_approach(world: Dictionary,delta: float) -> bool:
 var nav: Dictionary=world.crew.navigation
 var station:=current(world.manifest,nav)
 if station.is_empty():nav.mode="idle";nav.station_target=false;return true
 var target:=FrontierCrewWorld.vector(station.position)
 var point:=FrontierCrewWorld.vector(nav.position)
 if station.get("fixed_port",false):
  var previous:=definition(world.manifest,int(nav.system),-1,maxf(0,float(nav.orbit_time)-delta),station.id)
  point+=target-FrontierCrewWorld.vector(previous.position)
 var direction: Vector3=(target-point).normalized()
 # Route above the orbital plane and stellar hazard instead of crossing the star.
 var segment:=target-point
 var nearest:=point+segment*clampf(-point.dot(segment)/maxf(segment.length_squared(),1),0,1)
 if nearest.length()<float(FrontierUniverse.star_settings(world.manifest,int(nav.system)).star_warning_radius)+1000:
  direction=(Vector3(0,float(config().altitude),0)-point).normalized()
 var obstacles: Array=[]
 for i in FrontierUniverse.body_count(world.manifest,int(nav.system)):
  var ordinal:=FrontierUniverse.first_ordinal(world.manifest,int(nav.system))+i
  var body:=FrontierUniverse.body(world.manifest,ordinal)
  var center:=FrontierUniverse.position(world.manifest,ordinal,float(nav.orbit_time))
  obstacles.append({"point":center,"radius":FrontierUniverse.navigation_radius(body)+300})
  for moon in int(body.get("moons",0)):
   obstacles.append({"point":center+FrontierUniverse.moon_offset(body,moon,float(nav.orbit_time)),"radius":FrontierUniverse.moon_radius(body,moon)+250})
 for obstacle in obstacles:
  var route:=direction*point.distance_to(target)
  var offset: Vector3=obstacle.point-point
  var along:=clampf(offset.dot(route)/maxf(route.length_squared(),1),0,1)
  if (point+route*along).distance_to(obstacle.point)<float(obstacle.radius) and offset.dot(direction)>0:
   var side:=direction.cross(Vector3.UP).normalized()
   if side.length_squared()<.5:side=Vector3.RIGHT
   direction=(obstacle.point+side*(float(obstacle.radius)+600)-point).normalized()
 var gap:=maxf(0,point.distance_to(target)-float(config().approach_distance))
 nav.speed=move_toward(float(nav.speed),minf(float(config().approach_speed)*float(FrontierVesselRefit.stats(world).speed),sqrt(2.0*float(config().approach_acceleration)*gap)),float(config().approach_acceleration)*delta)
 point+=direction*minf(float(nav.speed)*delta,gap)
 nav.position=FrontierExpeditionBusiness.array(point);nav.direction=FrontierExpeditionBusiness.array(direction);world.flight_position=nav.position.duplicate()
 if gap>3:return false
 nav.mode="idle";nav.manual=true;nav.station_target=false;nav.speed=0
 if station.get("fixed_port",false):nav.station_docked=station.id;identify(world,station)
 for member in world.crew.members.values():member.ready=false
 return true
static func identify(world: Dictionary,station: Dictionary) -> void:
 if not station.get("fixed_port",false):return
 var row:=FrontierCorporations.candidate("space_y_port" if int(station.body)==3 else "space_y_earth_port",station.id,station.position,FrontierUniverse.body_id(world.manifest,int(station.body)))
 FrontierCorporations.record(world,row)
static func drift_docked(world: Dictionary,old_time: float) -> bool:
 var nav: Dictionary=world.crew.navigation
 var id: String=nav.get("station_docked","")
 if id.is_empty() or nav.mode!="idle":return false
 var station:=definition(world.manifest,int(nav.system),-1,float(nav.orbit_time),id)
 if station.is_empty():nav.erase("station_docked");return false
 var previous:=definition(world.manifest,int(nav.system),-1,old_time,id)
 var point:=FrontierCrewWorld.vector(nav.position)+FrontierCrewWorld.vector(station.position)-FrontierCrewWorld.vector(previous.position)
 nav.position=FrontierExpeditionBusiness.array(point);world.flight_position=nav.position.duplicate();nav.speed=0
 return true
static func validate(world: Dictionary) -> String:
 var nav: Dictionary=world.get("crew",{}).get("navigation",{})
 if not str(nav.get("station_docked","")).is_empty():
  var id: String=nav.station_docked
  if nav.get("mode")!="idle" or nav.get("station_id")!=id or not FrontierOrbitalPorts.BODIES.has(id):return "접안 기준 주소 오류"
  var station:=current(world.manifest,nav,id)
  if station.is_empty() or not available(world,station):return "접안 위치 오류"
 var markets: Variant=world.get("station_markets",{})
 if not markets is Dictionary or markets.size()>125002:return "정거장 장부 구조 오류"
 for key in markets:
  if not key is String:return "정거장 주소 오류"
  var index:=0
  if not FrontierOrbitalPorts.BODIES.has(key):
   if not key.is_valid_int() or str(int(key))!=key or int(key)<0 or int(key)>FrontierUniverse.system_index(world.manifest,int(world.manifest.settings.planet_count)-1):return "정거장 주소 오류"
   index=int(key)
  var original:=market(world.manifest,index,key)
  var stock: Variant=markets[key]
  if definition(world.manifest,index,int(nav.get("first_stellar_system",-1)),0,key).is_empty() or original.is_empty() or not stock is Dictionary or stock.size()!=original.stock.size():return "정거장 재고 구조 오류"
  for id in stock:
   if not original.stock.has(id) or not FrontierExpeditionBusiness.integer(stock[id],0,1 if id.begins_with("hull:") else int(original.get("capacities",{}).get(id,config().max_stock))):return "정거장 재고 수량 오류"
 return Economy.validate(world)
