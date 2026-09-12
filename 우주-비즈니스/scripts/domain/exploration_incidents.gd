class_name FrontierExplorationIncidents
extends RefCounted
## Host-owned encounters. Authored geometry and field actions, not scanner-stage rewards.
static var _config: Dictionary={}
static var _tiles: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/exploration_incidents.json"))
 return _config
static func definition(id: String) -> Dictionary:return config().items.get(id,{})
static func ensure(world: Dictionary) -> void:
 if not world.has("incidents"):world.incidents={"version":1,"records":{}}
static func records(world: Dictionary) -> Dictionary:return world.get("incidents",{}).get("records",{})
static func key(row: Dictionary) -> String:return str(row.body_id)+"/"+str(row.id)
static func array(p: Vector3) -> Array:return [p.x,p.y,p.z]
static func point(row: Dictionary,offset: Vector3) -> Vector3:return FrontierCrewWorld.vector(row.position)+offset.rotated(Vector3.UP,float(row.yaw))
static func field(body: Dictionary) -> FrontierTerrainField:
 var f:=FrontierTerrainField.new();f.configure(int(body.streams.terrain),[],24.0,body.get("terrain_traits",{}));return f
static func tile(body: Dictionary,f: FrontierTerrainField,cell: Vector2i) -> Array:
 var cache_key: String=body.id+":"+str(cell)
 if _tiles.has(cache_key):return _tiles[cache_key]
 var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(int(body.streams.discovery),"incidents-v1:"+str(cell))
 var pool: Array=[];var profile:=FrontierEcology.profile(body)
 for id in config().items:
  var d:=definition(id)
  if d.get("generation","")=="independent":continue
  if int(d.tier)>int(body.planet_tier):continue
  if d.mode=="seismic" or d.get("native_role","")=="cave":continue
  if d.has("native_role") and FrontierNativeIncidents.candidates(body,d.native_role).is_empty():continue
  if d.mode=="ice" and float(profile.temperature)>0:continue
  if d.mode=="scavenger" and profile.origin!="established":continue
  pool.append({"id":id,"roll":rng.randf()})
 pool.sort_custom(func(a,b):return a.roll<b.roll)
 var rows: Array=[];var span: float=config().tile_size
 for candidate in pool:
  if rows.size()>=int(config().density[str(int(body.planet_tier))]):break
  for attempt in 28:
   var at:=Vector3((cell.x+rng.randf_range(.15,.85))*span,0,(cell.y+rng.randf_range(.15,.85))*span)
   at.y=f.height(at.x,at.z)
   if Vector2(at.x,at.z).length()<110 or maxf(absf(at.x),absf(at.z))>8000:continue
   if FrontierSurfaceDrainage.liquid(f.traits) and at.y< -2.5:continue
   var yaw:=rng.randf()*TAU
   var flat:=true
   for offset in [Vector3(0,0,8),Vector3(0,0,-8),Vector3(6,0,0),Vector3(-6,0,0)]:
    var p: Vector3=at+offset.rotated(Vector3.UP,yaw)
    if absf(f.height(p.x,p.z)-at.y)>1.2:flat=false;break
   if not flat or rows.any(func(row):return FrontierCrewWorld.vector(row.position).distance_to(at)<120):continue
   var row: Dictionary={"id":"incident:%d:%d:%s"%[cell.x,cell.y,candidate.id],"template":candidate.id,"body_id":body.id,"position":array(at),"yaw":yaw,"tier":int(body.planet_tier)}
   var relay:=point(row,Vector3(0,0,55));relay.y=f.height(relay.x,relay.z)
   var battery:=point(row,Vector3(28,0,16));battery.y=f.height(battery.x,battery.z)
   row.relay=array(relay);row.battery_position=array(battery)
   row.path=[]
   for i in 13:
    var p: Vector3=at.lerp(relay,float(i)/12.0);p.y=f.height(p.x,p.z)+.35;row.path.append(array(p))
   if definition(row.template).has("native_role"):
    row.native=FrontierNativeIncidents.choose(body,row)
    if row.native.is_empty():continue
    for p in row.path:p[1]-=.35
    if not FrontierNativeIncidents.walkable_surface(row,f):continue
   rows.append(row);break
 # A seismic pocket branches from an existing seeded chamber, never replaces its graph.
 if int(body.planet_tier)>=2 and f.caves!=null:
  var cave:=f.caves.system_at(cell.x*span+span*.5,cell.y*span+span*.5)
  if not cave.chambers.is_empty():
   var chamber: Dictionary=cave.chambers[0];var center: Vector3=chamber.center
   if floori(center.x/span)==cell.x and floori(center.z/span)==cell.y:
    var side:=Vector3(1,0,0)
    if cave.segments.size()>0:
     var delta: Vector3=cave.segments[0].b-cave.segments[0].a;side=Vector3(-delta.z,0,delta.x).normalized()
    var end: Vector3=center+side*(float(chamber.radius)+12)-Vector3.UP*4
    var depth: float=f.base_height(end.x,end.z)-end.y
    if depth>8 and depth<185 and f.density(end)>0:
     var yaw:=fposmod(atan2(side.x,side.z),TAU)
     rows.append({"id":"incident:%d:%d:seismic_gem_chamber"%[cell.x,cell.y],"template":"seismic_gem_chamber","body_id":body.id,"position":array(end),"yaw":yaw,"tier":int(body.planet_tier),"relay":array(center),"battery_position":array(center),"path":[]})
 if int(body.planet_tier)>=2 and f.caves!=null and not FrontierNativeIncidents.candidates(body,"cave").is_empty():
  var cave:=f.caves.system_at(cell.x*span+span*.5,cell.y*span+span*.5)
  if not cave.chambers.is_empty():
   var chamber: Dictionary=cave.chambers[0];var center: Vector3=chamber.center
   if floori(center.x/span)==cell.x and floori(center.z/span)==cell.y:
    var row: Dictionary={"id":"incident:%d:%d:native_cave_presence"%[cell.x,cell.y],"template":"native_cave_presence","body_id":body.id,"position":array(center),"yaw":0.0,"tier":int(body.planet_tier),"path":[]}
    row.native=FrontierNativeIncidents.choose(body,row)
    var fits: bool=not row.native.is_empty() and maxf(float(row.native.height),maxf(float(row.native.width),float(row.native.length)))<float(chamber.radius)*.95
    if fits:
     for i in 13:
      var p:=center+Vector3((float(i)/12.0-.5)*float(chamber.radius)*.8,0,0)
      var steps:=0
      while f.density(p)<=0 and steps<ceili(float(chamber.radius)*12):p.y-=.1;steps+=1
      p.y+=.12
      if steps==0 or f.density(p+Vector3.UP*float(row.native.height))>0:fits=false;break
      row.path.append(array(p))
     if fits:
      row.position=row.path[0].duplicate();row.relay=row.path[-1].duplicate();row.battery_position=row.position.duplicate();rows.append(row)
 var storm: Dictionary=preload("res://scripts/domain/storm_archive.gd").spawn(body,f,cell,rows)
 if not storm.is_empty():rows.append(storm)
 var remote: Dictionary=preload("res://scripts/domain/remote_incidents.gd").spawn(body,f,cell,rows)
 if not remote.is_empty():rows.append(remote)
 if _tiles.size()>128:_tiles.erase(_tiles.keys()[0])
 _tiles[cache_key]=rows;return rows
static func nearby(body: Dictionary,f: FrontierTerrainField,p: Vector3) -> Array:
 var span: float=config().tile_size;var cell:=Vector2i(floori(p.x/span),floori(p.z/span));var result: Array=[]
 for x in range(cell.x-1,cell.x+2):
  for z in range(cell.y-1,cell.y+2):result.append_array(tile(body,f,Vector2i(x,z)))
 return result
static func create(row: Dictionary) -> Dictionary:
 var record:=row.duplicate(true)
 if record.has("native"):FrontierNativeIncidents.initialize(record)
 record.phase="idle";record.time=0.0;record.age=0.0;record.hp=float(config().robot.health);record.hits=0;record.open=false;record.powered=false;record.claimed=false;record.carrier="";record.battery_carrier="";record.battery_installed=false;record.battery_ground=record.battery_position.duplicate();record.cargo_ground=[];record.gems=0;record.serial=0;record.aim=[];record.target="";record.discoverer="";record.seen=false;record.materialized=false
 if definition(row.template).mode=="robot":
  record.shield_max=float(config().robot.shield_tier3) if int(row.tier)>=3 else 0.0;record.shield=record.shield_max;record.shield_wait=0.0
 return record
static func is_present(world: Dictionary,actor: String,row: Dictionary) -> bool:
 if not world.crew.members.has(actor):return false
 var member: Dictionary=world.crew.members[actor]
 return member.area=="surface" and not member.aboard and FrontierShuttles.context(world,actor).location==row.body_id
static func carriers(world: Dictionary,actor: String) -> bool:
 for row in records(world).values():
  if row.carrier==actor or row.battery_carrier==actor:return true
 return false
static func moving_point(row: Dictionary) -> Vector3:
 if row.has("native"):return FrontierNativeIncidents.position(row)
 var mode: String=definition(row.template).mode
 if mode=="scavenger":
  var points: Array=row.path
  if points.is_empty():return point(row,Vector3.ZERO)
  var phase: float=fmod(float(row.age)*.095,2.0);var travel: float=1.0-absf(phase-1.0)
  var index: float=travel*(points.size()-1);var lo:=floori(index)
  return FrontierCrewWorld.vector(points[lo]).lerp(FrontierCrewWorld.vector(points[mini(lo+1,points.size()-1)]),index-lo)
 if mode=="drone" and not row.open:
  return point(row,Vector3(sin(float(row.age)*.38)*7,2.0+sin(float(row.age)*.71)*.35,cos(float(row.age)*.38)*5))
 return point(row,Vector3(0,.7,0))
static func cargo_point(row: Dictionary) -> Vector3:
 if not row.cargo_ground.is_empty():return FrontierCrewWorld.vector(row.cargo_ground)
 match definition(row.template).mode:
  "wreck","power":return point(row,Vector3(0,.65,-4.4))
  "carry":return point(row,Vector3(0,5.15,0))
  "scavenger","native":return point(row,Vector3(0,.45,-2))
  "ice":return point(row,Vector3(0,.45,-2))
 return point(row,Vector3(0,.7,0))
static func targets(row: Dictionary) -> Array:
 if row.claimed:return []
 var mode: String=definition(row.template).mode
 var result: Array=[]
 if mode in ["wreck","power"]:
  var needs_power: bool=mode=="power" or int(row.tier)>=2
  if needs_power and not row.battery_installed:
   if row.battery_carrier=="":result.append({"part":"battery","point":FrontierCrewWorld.vector(row.battery_ground),"action":"F 배터리 들기"})
   result.append({"part":"socket","point":point(row,Vector3(2.2,1.0,2.8)),"action":"F 배터리 연결"})
  if mode=="power" and not row.powered:result.append({"part":"repair","point":FrontierCrewWorld.vector(row.battery_position)+Vector3(0,1.1,-2),"action":"F 구리 2개로 전력선 수리"})
  if not row.open:result.append({"part":"hatch","point":point(row,Vector3(0,1.6,2.4)),"action":"도구로 해치 파괴"})
  if row.open:result.append({"part":"cargo","point":cargo_point(row),"action":"F 화물 회수"})
 elif mode=="robot":
  if row.hp>0:result.append({"part":"robot","point":point(row,Vector3(0,1.5,0)),"action":"공격무기로 교전"+(" · 실드 %.0f / %.0f"%[float(row.get("shield",0)),float(row.get("shield_max",0))] if float(row.get("shield_max",0))>0 else "")})
  else:result.append({"part":"cargo","point":cargo_point(row),"action":"F 쿠퍼테크 부품 회수"})
 elif mode=="ice":
  if not row.open:result.append({"part":"ice","point":point(row,Vector3(0,1.3,1.6)),"action":"지형 변환기로 얼음 굴착"})
  else:result.append({"part":"cargo","point":cargo_point(row),"action":"F 보존 화물 회수"})
 elif mode=="seismic":
  if row.open and int(row.gems)<int(config().seismic.gems):result.append({"part":"gems","point":point(row,Vector3(0,-7.2,-1)),"action":"Mk.2 채집기로 보석 채굴"})
 elif mode=="drone" and not row.open:result.append({"part":"drone","point":moving_point(row),"action":"사격으로 드론 구동부 정지"})
 elif row.has("native"):
  result.append({"part":"cargo","point":cargo_point(row),"action":"F 탈락물·은닉품 회수" if FrontierNativeIncidents.available(row) else ("E로 현지 개체 분석" if not row.native_observed else "생물의 이동을 기다리세요")})
 else:
  if row.carrier=="":result.append({"part":"cargo","point":cargo_point(row),"action":"F 화물 들기" if mode in ["carry","drone"] else "F 은닉품 회수"})
 if preload("res://scripts/domain/storm_archive.gd").enabled(row):
  for target in result:
   if target.part=="repair":target.action="F 구리 2개로 피뢰 회로 수리"
   elif target.part=="socket":target.action="F 피뢰 배터리 연결"
 if row.carrier!="":result.append({"part":"delivery","point":FrontierCrewWorld.vector(row.relay)+Vector3.UP*.8,"action":"F 회수 지점에 화물 내려놓기"})
 return result
static func target(world: Dictionary,actor: String,aim: Vector3) -> Dictionary:
 if aim==Vector3.ZERO or not world.crew.members.has(actor):return {}
 var origin:=FrontierCrewWorld.vector(world.crew.members[actor].position)+Vector3.UP*1.72;var best:=float(config().tool_distance);var result: Dictionary={}
 var f: FrontierTerrainField
 for row in records(world).values():
  if not is_present(world,actor,row):continue
  if f==null:f=FrontierCrewSurface.field(FrontierShuttles.context(world,actor))
  for part in targets(row):
   var delta: Vector3=part.point-origin;var along: float=delta.dot(aim)
   if along<=0 or delta.length()>best or (delta-aim*along).length()> (1.3 if part.part=="robot" else .9):continue
   if not FrontierCrewSurface.visible_in_field(f,origin,part.point):continue
   result={"id":key(row),"part":part.part,"point":part.point,"action":part.action};best=delta.length()
 return result
static func hurt(world: Dictionary,actor: String,amount: float,kind: String="combat") -> void:
 var member: Dictionary=world.crew.members[actor]
 if FrontierCrewVitals.damage(member,amount,kind):
  member.position=FrontierCrewSurface.config().landing_spawn_positions[0].duplicate()
  member.incident_rescue=int(member.get("incident_rescue",0))+1
static func set_phase(row: Dictionary,phase: String) -> void:row.phase=phase;row.time=0.0;row.serial+=1
static func _carve(world: Dictionary,row: Dictionary) -> bool:
 var edits: Array=world.terrain_edits.get(row.body_id,[])
 if edits.size()+10>int(FrontierCrewSurface.config().maximum_edits_per_planet):return false
 var start:=FrontierCrewWorld.vector(row.relay);var end:=FrontierCrewWorld.vector(row.position)
 for i in 9:edits.append({"center":array(start.lerp(end,float(i)/8.0)),"radius":3.8 if i<8 else 8.0})
 world.terrain_edits[row.body_id]=edits;row.materialized=true;return true
static func tick(world: Dictionary,delta: float,actors: Array,obstacle: Callable=Callable(),connected: Array=[]) -> bool:
 if connected.is_empty():connected=actors
 ensure(world);var changed:=false;var bodies: Dictionary={}
 for actor in actors:
  var local:=FrontierShuttles.context(world,actor)
  if not FrontierCrewSurface.landed(local) or world.crew.members[actor].aboard:continue
  var body:=FrontierUniverse.body_from_id(world.manifest,local.location);var f:=FrontierCrewSurface.field(local);var p:=FrontierCrewWorld.vector(world.crew.members[actor].position)
  bodies[body.id]=f
  for source in nearby(body,f,p):
   if records(world).has(key(source)):continue
   if minf(p.distance_to(FrontierCrewWorld.vector(source.position)),p.distance_to(FrontierCrewWorld.vector(source.relay)))>float(config().activation_distance):continue
   var occupied:=false
   for building in world.get("business",{}).get("sites",{}).get(body.id,{}).get("buildings",{}).values():
    if FrontierCrewWorld.vector(building.position).distance_to(FrontierCrewWorld.vector(source.position))<float(config().exclusion_radius):occupied=true;break
   if occupied:continue
   world.incidents.records[key(source)]=create(source);changed=true
 for row in records(world).values():
  var present: Array=[]
  for actor in actors:
   if is_present(world,actor,row) and minf(FrontierCrewWorld.vector(world.crew.members[actor].position).distance_to(FrontierCrewWorld.vector(row.position)),FrontierCrewWorld.vector(world.crew.members[actor].position).distance_to(FrontierCrewWorld.vector(row.relay)))<float(config().activation_distance):present.append(actor)
  for slot in ["carrier","battery_carrier"]:
   var actor: String=row[slot]
   if actor!="" and (actor not in connected or not is_present(world,actor,row) or int(world.crew.members[actor].get("vitals",{}).get("rescue_serial",0))>int(row.get(slot+"_rescue",0))):
    row["cargo_ground" if slot=="carrier" else "battery_ground"]=array(point(row,Vector3(0,.7,3))) if slot=="carrier" else row.battery_position.duplicate();row[slot]="";changed=true
  if present.is_empty() or (row.claimed and definition(row.template).mode!="seismic"):continue
  row.age+=delta;row.time+=delta
  var p:=FrontierCrewWorld.vector(world.crew.members[present[0]].position);var mode: String=definition(row.template).mode
  if not row.seen and p.distance_to(FrontierCrewWorld.vector(row.position))<35:row.seen=true;row.discoverer=present[0];changed=true
  if preload("res://scripts/domain/storm_archive.gd").tick(world,row,delta,present,obstacle):changed=true
  if row.has("native"):
   if FrontierNativeIncidents.tick(world,row,present,delta,bodies[row.body_id]):changed=true
  elif mode=="robot" and row.hp>0:
   row.shield_wait=maxf(0,float(row.get("shield_wait",0))-delta)
   if row.shield_wait<=0:row.shield=minf(float(row.get("shield_max",0)),float(row.get("shield",0))+float(config().robot.shield_rate)*delta)
   var robot_cfg: Dictionary=config().robot;var target_actor: String="";var nearest:=float(robot_cfg.range)
   for actor in present:
    var distance: float=FrontierCrewWorld.vector(world.crew.members[actor].position).distance_to(FrontierCrewWorld.vector(row.position))
    if distance<nearest:nearest=distance;target_actor=actor
   if row.phase=="idle" and nearest<float(robot_cfg.wake_distance):set_phase(row,"waking");changed=true
   elif row.phase=="waking" and row.time>=robot_cfg.wake_seconds:set_phase(row,"cooling");changed=true
   elif row.phase=="cooling" and row.time>=robot_cfg.cool_seconds and target_actor!="":
    row.aim=array(FrontierCrewWorld.vector(world.crew.members[target_actor].position)+Vector3.UP*(FrontierFirearms.eye(world.crew.members[target_actor])-1.0));row.target=target_actor;set_phase(row,"aiming");changed=true
   elif row.phase=="aiming" and row.time>=robot_cfg.aim_seconds:
    var start:=point(row,Vector3(0,1.5,0));var end:=FrontierCrewWorld.vector(row.aim)+Vector3.UP
    var flight: Vector3=(end-start).normalized();var cover:=FrontierCombatCover.intercept(world,row.body_id,start,flight,start.distance_to(end))
    if not cover.is_empty() and FrontierCrewSurface.visible_in_field(bodies[row.body_id],start,cover.point):
     var distance:=float(obstacle.call(target_actor if target_actor!="" else present[0],start,flight,float(cover.distance)+.1)) if obstacle.is_valid() else float(cover.distance)
     if distance>=float(cover.distance)-.15:FrontierCombatCover.damage(cover,float(robot_cfg.damage));row.aim=FrontierExplorationIncidents.array(cover.point-Vector3.UP)
     set_phase(row,"firing");changed=true;continue
    for actor in present:
     var at:=FrontierCrewWorld.vector(world.crew.members[actor].position)+Vector3.UP*(.8 if world.crew.members[actor].loadout.get("crouched",false) else 1.3);var line:=end-start;var t:=clampf((at-start).dot(line)/maxf(.01,line.length_squared()),0,1)
     if at.distance_to(start+line*t)>(.4 if world.crew.members[actor].loadout.get("crouched",false) else .65):continue
     if not FrontierCrewSurface.visible_in_field(bodies[row.body_id],start,at):continue
     if obstacle.is_valid() and float(obstacle.call(actor,start,(at-start).normalized(),start.distance_to(at)))<start.distance_to(at)-.5:continue
     hurt(world,actor,float(robot_cfg.damage))
    set_phase(row,"firing");changed=true
   elif row.phase=="firing" and row.time>=robot_cfg.fire_seconds:set_phase(row,"cooling");changed=true
  elif mode=="seismic":
   var trigger:=FrontierCrewWorld.vector(row.relay)
   if row.phase=="idle" and p.distance_to(trigger)<16 and bodies[row.body_id].height(p.x,p.z)-p.y>3:set_phase(row,"quake");changed=true
   elif row.phase=="quake" and row.time>=float(config().seismic.warning_seconds):
    if _carve(world,row):row.open=true;set_phase(row,"quiet");changed=true
   elif row.open:
    if row.phase=="quiet" and row.time>=float(config().seismic.period)-float(config().seismic.blast_warning):set_phase(row,"warning");changed=true
    elif row.phase=="warning" and row.time>=float(config().seismic.blast_warning):
     var center:=point(row,Vector3(0,-6.5,0))
     for actor in present:
      var at:=FrontierCrewWorld.vector(world.crew.members[actor].position)+Vector3.UP
      if at.distance_to(center)<float(config().seismic.blast_radius) and FrontierCrewSurface.visible_in_field(bodies[row.body_id],center,at):hurt(world,actor,float(config().seismic.damage),"blast")
     set_phase(row,"blast");changed=true
    elif row.phase=="blast" and row.time>.5:set_phase(row,"quiet");changed=true
 return changed
static func apply(world: Dictionary,actor: String,args: Dictionary,tool_action: bool,obstacle: Callable=Callable()) -> String:
 if args.get("part")=="drop":
  var carried: Dictionary=records(world).get(str(args.get("id","")),{})
  if carried.is_empty() or not is_present(world,actor,carried):return "운반 중인 현장 화물이 없습니다."
  var slot: String="carrier" if carried.carrier==actor else ("battery_carrier" if carried.battery_carrier==actor else "")
  if slot.is_empty():return "직접 운반 중인 화물만 내려놓을 수 있습니다."
  carried["cargo_ground" if slot=="carrier" else "battery_ground"]=array(FrontierCrewWorld.vector(world.crew.members[actor].position)+Vector3.UP*.35)
  carried[slot]="";carried.serial+=1;return ""
 var aim:=FrontierCrewSurface.direction(args.get("aim"));var hit:=target(world,actor,aim)
 if hit.is_empty() or args.get("id")!=hit.id or args.get("part")!=hit.part:return "실제 사건 대상을 조준하세요."
 var row: Dictionary=records(world)[hit.id];var mode: String=definition(row.template).mode
 var origin:=FrontierCrewWorld.vector(world.crew.members[actor].position)+Vector3.UP*1.72
 if not tool_action and origin.distance_to(hit.point)>float(config().action_distance):return "대상 가까이 접근하세요."
 if obstacle.is_valid() and float(obstacle.call(actor,origin,aim,origin.distance_to(hit.point)))<origin.distance_to(hit.point)-.7:return "엄폐물에 가려져 있습니다."
 var tool:=FrontierEquipment.active(world.crew.members[actor])
 if tool_action:
  var expected: String="pulse" if hit.part in ["robot","drone"] else ("miner" if hit.part=="gems" else "terrain")
  if tool.get("kind")!=expected:return "공격무기가 필요합니다." if expected=="pulse" else ("채집기가 필요합니다." if expected=="miner" else "지형 변환기가 필요합니다.")
  if obstacle.is_valid() and float(obstacle.call(actor,origin,aim,origin.distance_to(hit.point)))<origin.distance_to(hit.point)-1.5:return "엄폐물에 가려져 있습니다."
  match hit.part:
   "robot":
    var core_delta:=point(row,Vector3(0,1.98,.52))-origin
    var weak_hit: bool=row.phase=="cooling" and (core_delta-aim*core_delta.dot(aim)).length()<.4
    var split:=FrontierCrewVitals.split_shield_damage(float(row.get("shield",0)),float(tool.damage)*(float(config().robot.weak_factor) if weak_hit else 1.0),float(tool.get("shield_multiplier",1.0)))
    row.shield=maxf(0,float(row.get("shield",0))-float(split.absorbed));row.shield_wait=float(config().robot.shield_delay)
    row.hp=maxf(0,row.hp-float(split.health))
    if row.hp<=0:
     set_phase(row,"destroyed");FrontierSuitModules.on_kill(world.crew.members[actor])
   "drone":
    row.hits+=1
    if row.hits>=int(config().tool.drone_hits):
     var landed_at:=moving_point(row);var ground:=FrontierCrewSurface.field(FrontierShuttles.context(world,actor));landed_at.y=ground.height(landed_at.x,landed_at.z)+.35
     row.cargo_ground=array(landed_at);row.open=true;set_phase(row,"disabled")
   "hatch":
    if (mode=="power" or int(row.tier)>=2) and not row.battery_installed:return "옆 전원 소켓에 배터리를 연결하세요."
    if mode=="power" and not row.powered:return "끊어진 전력선을 수리하세요."
    row.hits+=1
    if row.hits>=int(config().tool.hatch_hits):row.open=true;set_phase(row,"opened")
   "ice":
    row.hits+=1
    if row.hits>=int(config().tool.ice_hits):row.open=true;set_phase(row,"opened")
   "gems":
    if int(tool.get("tier",0))<int(config().seismic.required_tier):return "Mk.2 이상 채집기가 필요합니다."
    if int(row.gems)+1>=int(config().seismic.gems):
     var module_error:=FrontierSuitModules.drop(world,actor,key(row),int(row.tier),mode)
     if not module_error.is_empty():return module_error
    var reason:=reward(world,actor,{"sapphire":1})
    if not reason.is_empty():return reason
    row.gems+=1
    if int(row.gems)>=int(config().seismic.gems):row.claimed=true
   _:return "이 대상은 도구로 작업하지 않습니다."
 else:
  match hit.part:
   "battery":
    if carriers(world,actor):return "운반 중인 물건을 먼저 내려놓으세요."
    row.battery_carrier=actor;row.battery_carrier_rescue=int(world.crew.members[actor].get("vitals",{}).get("rescue_serial",0))
   "socket":
    if row.battery_carrier!=actor:return "배터리를 직접 운반해 오세요."
    row.battery_carrier="";row.battery_installed=true
   "repair":
    FrontierItemInventory.merge_legacy(world,actor)
    var bag:=FrontierExpeditionBusiness.bag(world,actor)
    if int(bag.get("copper",0))<2:return "구리 2개가 필요합니다."
    bag.copper-=2;row.powered=true
   "cargo":
    if mode in ["carry","drone"]:
     if carriers(world,actor):return "운반 중인 물건을 먼저 내려놓으세요."
     row.carrier=actor;row.carrier_rescue=int(world.crew.members[actor].get("vitals",{}).get("rescue_serial",0))
    else:
     var reason:=recover(world,actor,row)
     if not reason.is_empty():return reason
     row.claimed=true;set_phase(row,"recovered")
   "delivery":
    if row.carrier!=actor:return "이 화물을 운반하는 승무원이 내려놓아야 합니다."
    var reason:=recover(world,actor,row)
    if not reason.is_empty():return reason
    row.carrier="";row.claimed=true;set_phase(row,"recovered")
   _:return "도구를 사용하거나 사건에 직접 대응하세요."
 row.seen=true;row.serial+=1
 return ""
static func reward(world: Dictionary,actor: String,value: Dictionary,equipment: String="") -> String:
 FrontierItemInventory.merge_legacy(world,actor)
 if not FrontierItemInventory.fits(world,actor,value):return "배낭 공간이 부족합니다. 화물은 현장에 남습니다."
 if equipment!="":
  var member: Dictionary=world.crew.members[actor];var after:=FrontierExpeditionBusiness.bag(world,actor).duplicate()
  FrontierExpeditionBusiness.transfer(after,value,1)
  if FrontierItemInventory.used(after,member.loadout.items.size()+1)>FrontierItemInventory.capacity(member):return "회수 장비를 넣을 배낭 공간이 필요합니다."
  member.loadout.counter+=1;member.loadout.items["crafted:"+str(int(member.loadout.counter))]=equipment
 if not world.has("business"):world.business=FrontierExpeditionBusiness.create()
 if not world.business.bags.has(actor):world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
 FrontierExpeditionBusiness.transfer(world.business.bags[actor],value,1);return ""
static func snapshot(world: Dictionary,actor: String) -> Dictionary:
 var result: Dictionary={"version":1,"records":{}}
 if not world.crew.members.has(actor):return result
 var local:=FrontierShuttles.context(world,actor)
 for id in records(world):
  var row: Dictionary=records(world)[id]
  if row.body_id==local.location and (row.carrier==actor or row.battery_carrier==actor or minf(FrontierCrewWorld.vector(world.crew.members[actor].position).distance_to(FrontierCrewWorld.vector(row.position)),FrontierCrewWorld.vector(world.crew.members[actor].position).distance_to(FrontierCrewWorld.vector(row.relay)))<float(config().view_distance)+80):result.records[id]=row.duplicate(true)
 return result
static func validate(world: Dictionary) -> String:
 if not world.has("incidents"):return ""
 var state: Variant=world.incidents
 if not state is Dictionary or state.get("version")!=1 or not state.get("records") is Dictionary:return "사건 저장 형식 오류"
 for id in state.records:
  var row: Variant=state.records[id]
  if not row is Dictionary or definition(str(row.get("template",""))).is_empty():return "사건 종류 오류"
  for field_name in ["position","relay","battery_position","battery_ground"]:
   if not FrontierUniverse._vector3_array(row.get(field_name)):return "사건 위치 오류"
  if not row.get("body_id") is String or FrontierUniverse.ordinal_of(world.manifest,row.body_id)<0 or not row.get("id") is String or id!=key(row):return "사건 식별 오류"
  if not FrontierUniverse._finite(row.get("yaw"),0,TAU) or not FrontierExpeditionBusiness.integer(row.get("tier"),1,5):return "사건 생성 정보 오류"
  for field_name in ["time","age","hp","hits","gems","serial"]:
   if not FrontierUniverse._finite(row.get(field_name),0,9007199254740000):return "사건 진행 수치 오류"
  for field_name in ["shield","shield_max","shield_wait"]:
   if not FrontierUniverse._finite(row.get(field_name,0),0,float(config().robot.shield_tier3)):return "사건 실드 기록 오류"
  if float(row.get("shield",0))>float(row.get("shield_max",0)):return "사건 실드 잔량 오류"
  if row.hp>float(config().robot.health) or row.gems>int(config().seismic.gems):return "사건 잔량 오류"
  for field_name in ["open","powered","claimed","battery_installed","seen","materialized"]:
   if not row.get(field_name) is bool:return "사건 상태 오류"
  for field_name in ["carrier","battery_carrier","target","discoverer"]:
   if not row.get(field_name) is String or (row[field_name]!="" and not world.crew.members.has(row[field_name])):return "사건 승무원 오류"
  if row.get("phase") not in ["idle","waking","cooling","aiming","firing","destroyed","disabled","opened","recovered","quake","quiet","warning","blast"]:return "사건 단계 오류"
  for field_name in ["cargo_ground","aim"]:
   if not row.get(field_name) is Array or (not row[field_name].is_empty() and not FrontierUniverse._vector3_array(row[field_name])):return "사건 위치 상태 오류"
  if not row.get("path") is Array or row.path.size()>13:return "사건 이동 경로 오류"
  for p in row.path:
   if not FrontierUniverse._vector3_array(p):return "사건 이동 지점 오류"
  if not preload("res://scripts/domain/storm_archive.gd").validate(world,row):return "폭풍 기록고의 복원 결과 오류"
  if not FrontierNativeIncidents.validate(world,row):return "현지 생물 사건 기록 오류"
 return ""

static func recover(world: Dictionary,actor: String,row: Dictionary) -> String:
 if not FrontierNativeIncidents.available(row):return "생물을 분석하고 이동한 뒤 현장 보상을 회수하세요."
 var error:=FrontierSuitModules.drop(world,actor,key(row),int(row.tier),str(definition(row.template).mode))
 if not error.is_empty():return error
 var result:=reward(world,actor,FrontierNativeIncidents.reward(row),str(definition(row.template).get("equipment",{}).get(str(int(row.tier)),"")))
 if not result.is_empty():return result
 var firearm_error:=FrontierFirearms.drop(world,actor,row)
 if not firearm_error.is_empty():return firearm_error
 if preload("res://scripts/domain/storm_archive.gd").enabled(row):return preload("res://scripts/domain/storm_archive.gd").recover(world,actor,row)
 return ""
