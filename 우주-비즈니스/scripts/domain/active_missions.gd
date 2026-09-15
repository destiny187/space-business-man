class_name FrontierActiveMissions
extends RefCounted
## Independent seeded sites. All progress/rewards are host owned incident records.
static var _config: Dictionary={}
static var _birds: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/active_missions.json"))
 return _config
static func enabled(row: Dictionary) -> bool:return config().templates.has(row.get("template",""))
static func rules(row: Dictionary) -> Dictionary:return config().tiers[str(int(row.tier))]
static func allowed(id: String,tier: int) -> bool:
 var d: Dictionary=config().templates.get(id,{})
 return not d.is_empty() and tier>=int(d.minimum_tier) and tier<=int(d.maximum_tier)
static func vec(p: Array) -> Vector3:return FrontierCrewWorld.vector(p)
static func arr(p: Vector3) -> Array:return FrontierExplorationIncidents.array(p)
static func at(row: Dictionary,offset: Vector3) -> Vector3:return FrontierExplorationIncidents.point(row,offset)
static func progress_text(row: Dictionary) -> String:
 if row.claimed:return "현장 목표 완료"
 if row.carrier!="":return "회수 신호기로 화물 운반 중"
 var m: Dictionary=row.mission
 match row.template:
  "runaway_convoy_intercept":return "수송기 정지  화물 회수 가능" if row.open else "수송기 구동부  %.0f / %.0f"%[float(m.drive_hp),float(rules(row).drive_hp)]
  "aerial_sensor_recovery":return "관찰  %.1f / %.1f초"%[float(m.observed),float(rules(row).observe_seconds)]
  "stranded_survey_rover":return "안전 지점 도착  구난 성과 회수" if row.open else "잔해 제거  %d / %d  배터리 %s"%[m.steps.filter(func(v):return int(v)>=int(rules(row).blocker_hits)).size(),m.steps.size(),"연결됨" if row.battery_installed else "필요"]
 return "완료한 목표  %d / %d"%[m.steps.filter(func(v):return int(v)>0).size(),m.steps.size()]
static func bird(body: Dictionary) -> Dictionary:
 if _birds.has(body.id):return _birds[body.id]
 var ecology: Dictionary={"planets":{}};var record:=FrontierEcology.ensure_planet(ecology,body);var result: Dictionary={}
 for lineage in record.lineages:
  var form:=FrontierEcologyCatalog.form(lineage.form_id)
  if form.get("locomotion_medium","")!="surface_air":continue
  result={"form_id":lineage.form_id,"look_id":lineage.look_id};break
 if _birds.size()>128:_birds.clear()
 _birds[body.id]=result;return result
static func spawn(body: Dictionary,f: FrontierTerrainField,cell: Vector2i,occupied: Array,force_id: String="") -> Array:
 if int(body.planet_tier)<2:return []
 var rng:=RandomNumberGenerator.new();rng.seed=FrontierUniverse.derive(int(body.streams.discovery),"active-missions-v1:"+str(cell))
 if force_id.is_empty() and rng.randf()>float(config().tile_chance):return []
 var pool: Array=[]
 for id in config().templates:
  if not allowed(id,int(body.planet_tier)) or (id=="freighter_rescue_chain" and force_id.is_empty()):continue
  if id=="aerial_sensor_recovery" and bird(body).is_empty():continue
  pool.append(id)
 if pool.is_empty() or (not force_id.is_empty() and force_id not in pool):return []
 var template: String=force_id if not force_id.is_empty() else str(pool[rng.randi_range(0,pool.size()-1)])
 var span:=float(FrontierExplorationIncidents.config().tile_size)
 for attempt in 24:
  var center:=Vector3((cell.x+rng.randf_range(.2,.8))*span,0,(cell.y+rng.randf_range(.2,.8))*span);center.y=f.height(center.x,center.z)
  if Vector2(center.x,center.z).length()<180 or maxf(absf(center.x),absf(center.z))>7800:continue
  if occupied.any(func(r):return center.distance_to(vec(r.get("home",r.position)))<150):continue
  var clear:=true
  # Check the whole authored footprint, including walking/vehicle corridors.
  for x in range(-4,5):
   for z in range(-4,5):
    var p:=center+Vector3(x*8.,0,z*8.);var h:=f.height(p.x,p.z)
    if absf(h-center.y)>2.2 or (FrontierSurfaceDrainage.liquid(f.traits) and h< -2.5):clear=false;break
   if not clear:break
  if not clear:continue
  var row: Dictionary={"id":"active:%d:%d:%s"%[cell.x,cell.y,template],"template":template,"body_id":body.id,"position":arr(center),"yaw":0.0,"tier":int(body.planet_tier),"relay":arr(center+Vector3(0,0,30)),"battery_position":arr(center+Vector3(-8,0,20)),"path":[],"mission_version":1}
  for key in ["relay","battery_position"]:row[key][1]=f.height(float(row[key][0]),float(row[key][2]))
  var cfg:=rules(row);var anchors: Array=[]
  if template=="cliff_relay_run":
   var rise:=7.0 if int(row.tier)==2 else 10.0
   for offset in [Vector3.ZERO,Vector3(12,rise,0),Vector3(12,rise*2,12),Vector3(0,rise*3,12)]:anchors.append(arr(center+offset+Vector3.UP*.3))
  else:
   var count:=int(cfg.power_nodes) if template=="coopertech_relay_raid" else int(cfg.nodes)
   if template=="freighter_rescue_chain":count=int(cfg.cargo_count)
   for i in count:
    var angle:=TAU*float(i)/count;var p:=center+Vector3(cos(angle)*20,0,sin(angle)*20);p.y=f.height(p.x,p.z)+.3;anchors.append(arr(p))
  # Closed convoy circuit; open rover route ends at the return beacon.
  for i in 13:
   var angle:=TAU*float(i)/12.;var p:=center+Vector3(cos(angle)*22,0,sin(angle)*22)
   if template=="stranded_survey_rover":p=center+Vector3(-24+float(i)*4,0,0)
   p.y=f.height(p.x,p.z)+.15;row.path.append(arr(p))
  if template=="stranded_survey_rover":
   row.relay=row.path.back().duplicate();anchors=[]
   for i in range(1,int(cfg.nodes)+1):anchors.append(row.path[mini(11,i*2)].duplicate())
  var mission: Dictionary={"anchors":anchors,"steps":[],"angles":[PI,PI,PI],"drive_hp":float(cfg.drive_hp),"distance":0.0,"moving":row.path[0].duplicate(),"moving_yaw":0.0,"running":false,"observed":0.0,"cargo_index":-1,"delivered":0,"hazard_serial":0,"last_hazard":-1,"event":"","event_point":row.position.duplicate(),"rescue_id":""}
  for i in anchors.size():mission.steps.append(0)
  if template=="aerial_sensor_recovery":
   mission.bird=bird(body).duplicate();mission.anchors=[arr(center+Vector3(0,8,0))];mission.steps=[0]
  row.mission=mission
  var rows: Array=[row]
  if template in ["runaway_convoy_intercept","coopertech_relay_raid"]:
   for i in int(cfg.guards):
    var role: String="sentry" if i==0 else ("raptor" if i%2 else "bastion")
    var point: Array=row.path[(i*3)%12].duplicate()
    rows.append({"squad_version":1,"squad_id":row.id,"mission_parent":row.id,"robot_role":role,"start_mode":"patrol","id":row.id+":guard:"+str(i),"template":FrontierCooperTechSquads.config().roles[role].template,"body_id":body.id,"position":point,"home":arr(center),"yaw":0.0,"tier":int(body.planet_tier),"relay":row.relay.duplicate(),"battery_position":point.duplicate(),"path":row.path.duplicate(true),"patrol_index":(i*3+1)%12})
  return rows
 return []
static func reward(row: Dictionary) -> Dictionary:
 var result: Dictionary={}
 for id in config().templates[row.template].reward:result[id]=maxi(1,roundi(float(config().templates[row.template].reward[id])*float(rules(row).reward)))
 return result
static func cargo_point(row: Dictionary) -> Vector3:
 if not row.cargo_ground.is_empty():return vec(row.cargo_ground)
 var m: Dictionary=row.mission
 match row.template:
  "cliff_relay_run":return vec(m.anchors.back())+Vector3(0,.8,-1)
  "runaway_convoy_intercept":return vec(m.moving)+Vector3.UP*1.1
  "aerial_sensor_recovery":return vec(m.anchors[0])+Vector3.UP*.8
  "freighter_rescue_chain":
   var index:=int(m.cargo_index)
   if index<0:
    for i in m.steps.size():
     if int(m.steps[i])==0:index=i;break
   return vec(m.anchors[maxi(0,index)])+Vector3.UP*.7
 return at(row,Vector3(0,.85,-3))
static func complete_steps(row: Dictionary) -> bool:
 for v in row.mission.steps:
  if int(v)==0:return false
 return true
static func event(row: Dictionary,kind: String,p: Vector3) -> void:
 row.serial+=1
 if kind!="blast":row.mission.revision=int(row.mission.get("revision",0))+1
 row.mission.event=kind;row.mission.event_point=arr(p);row.seen=true
static func bird_point(row: Dictionary) -> Vector3:
 var cfg:=rules(row);var t:=fposmod(float(row.age),float(cfg.bird_period));var rest:=float(cfg.bird_rest)
 if t<rest:return vec(row.mission.anchors[0])+Vector3(0,1,0)
 var flight: float=(t-rest)/(float(cfg.bird_period)-rest)
 return vec(row.mission.anchors[0])+Vector3(sin(flight*TAU)*14,1+sin(flight*PI)*9,(1-cos(flight*TAU))*9)
static func bird_away(row: Dictionary) -> bool:return bird_point(row).distance_to(vec(row.mission.anchors[0]))>9
static func hazard(row: Dictionary,index: int) -> String:
 var cfg:=rules(row);var t:=fposmod(float(row.age)+float(index)*float(cfg.hazard_period)/row.mission.anchors.size(),float(cfg.hazard_period))
 if t>=float(cfg.hazard_period)-.8:return "blast"
 if t>=float(cfg.hazard_period)-.8-float(cfg.hazard_warning):return "warning"
 return "quiet"
static func targets(row: Dictionary) -> Array:
 if row.claimed:return []
 var result: Array=[];var m: Dictionary=row.mission
 if row.carrier!="":return [{"part":"delivery","point":vec(row.relay)+Vector3.UP*.8,"action":"F 회수 신호기에 인계"}]
 match row.template:
  "cliff_relay_run":
   for i in 3:
    if int(m.steps[i])==0:result.append({"part":"rotate_"+str(i),"point":vec(m.anchors[i])+Vector3(0,1.1,1.0),"action":"F 안테나 회전  다음 수신부 연결"})
   if int(m.steps[0])*int(m.steps[1])*int(m.steps[2])>0:result.append({"part":"finish","point":cargo_point(row),"action":"F 복구 기록  부품 회수"})
  "runaway_convoy_intercept":
   if not row.open:
    result.append({"part":"drive","point":vec(m.moving)+Vector3(1.25,.75,0).rotated(Vector3.UP,float(m.moving_yaw)),"action":"구동부를 사격해 수송기 정지"})
    result.append({"part":"barrier","point":vec(row.path[0])+Vector3(3,1,0),"action":"F 진로 차단기 내리기"})
   else:result.append({"part":"cargo","point":cargo_point(row),"action":"F 수송 화물 들기"})
  "coopertech_relay_raid":
   for i in m.anchors.size():
    if int(m.steps[i])==0:result.append({"part":"power_"+str(i),"point":vec(m.anchors[i])+Vector3(0,1,1),"action":"F 외부 전원 차단"})
   if complete_steps(row):result.append({"part":"cargo","point":cargo_point(row),"action":"F 격실 코어 들기"})
  "vent_field_extraction":
   for i in m.anchors.size():
    if int(m.steps[i])==0:result.append({"part":"mine_"+str(i),"point":vec(m.anchors[i])+Vector3.UP*.7,"action":"채집기로 결정층 채굴  분출 전조 주의"})
   if complete_steps(row):result.append({"part":"finish","point":vec(row.relay)+Vector3.UP*.8,"action":"F 채굴 성과 회수"})
  "aerial_sensor_recovery":
   result.append({"part":"cargo","point":cargo_point(row),"action":"F 센서 들기" if float(m.observed)>=float(rules(row).observe_seconds) and bird_away(row) else "거리를 두고 관찰  새가 날아간 틈에 접근"})
  "stranded_survey_rover":
   for i in m.anchors.size():
    if int(m.steps[i])<int(rules(row).blocker_hits):result.append({"part":"clear_"+str(i),"point":vec(m.anchors[i])+Vector3(0,.7,1.3),"action":"지형 변환기로 이동로 잔해 제거"})
   if not row.battery_installed:
    if row.battery_carrier=="":result.append({"part":"battery","point":vec(row.battery_ground)+Vector3.UP*.3,"action":"F 구난 배터리 들기"})
    result.append({"part":"socket","point":vec(m.moving)+Vector3(1.25,1,0),"action":"F 구난 배터리 연결"})
   else:result.append({"part":"rover_toggle","point":vec(m.moving)+Vector3(1.25,1,0),"action":"F 로버 정지" if m.running else "F 로버 출발  가까이서 동행"})
   if row.open:result.append({"part":"finish","point":vec(row.relay)+Vector3.UP*.8,"action":"F 구난 부품 회수"})
  "freighter_rescue_chain":
   if int(m.cargo_index)>=0 and not row.cargo_ground.is_empty():
    return [{"part":"crate_"+str(int(m.cargo_index)),"point":vec(row.cargo_ground),"action":"F 내려놓은 화물 다시 들기"}]
   for i in m.anchors.size():
    if int(m.steps[i])==0:result.append({"part":"crate_"+str(i),"point":vec(m.anchors[i])+Vector3.UP*.7,"action":"F 유실 화물 들기"})
   if complete_steps(row):result.append({"part":"finish","point":vec(row.relay)+Vector3.UP*.8,"action":"F 수송선 구조 성과 회수"})
 return result
static func apply(world: Dictionary,actor: String,row: Dictionary,part: String,tool_action: bool,tool: Dictionary) -> String:
 var m: Dictionary=row.mission;var cfg:=rules(row)
 var p:=vec(world.crew.members[actor].position)
 if row.claimed:return "이미 회수한 현장입니다."
 if part.begins_with("mine_") or part.begins_with("clear_"):
  var mining:=part.begins_with("mine_");var i:=part.get_slice("_",1).to_int()
  if not tool_action or tool.get("kind")!=("miner" if mining else "terrain"):return "채집기를 사용하세요." if mining else "지형 변환기를 사용하세요."
  if mining and int(tool.get("tier",0))<int(cfg.tool_tier):return "Mk.%d 이상 채집기가 필요합니다."%int(cfg.tool_tier)
  m.steps[i]=1 if mining else mini(int(cfg.blocker_hits),int(m.steps[i])+1);event(row,"work",vec(m.anchors[i]));return ""
 if tool_action:return "이 장치는 F로 조작하세요."
 if part.begins_with("rotate_"):
  var i:=part.get_slice("_",1).to_int();m.angles[i]=fposmod(float(m.angles[i])+PI/4,TAU)
  var delta:=vec(m.anchors[i+1])-vec(m.anchors[i]);var target_yaw:=atan2(-delta.x,-delta.z)
  if absf(angle_difference(float(m.angles[i]),target_yaw))<.05:
   var f:=FrontierCrewSurface.field(world)
   if FrontierCrewSurface.visible_in_field(f,vec(m.anchors[i])+Vector3.UP*2.1,vec(m.anchors[i+1])+Vector3.UP*2.1):m.steps[i]=1
  event(row,"connect" if int(m.steps[i])==1 else "rotate",vec(m.anchors[i]));return ""
 if part.begins_with("power_"):
  var i:=part.get_slice("_",1).to_int();m.steps[i]=1;row.open=complete_steps(row);event(row,"connect",vec(m.anchors[i]));return ""
 if part=="barrier":m.running=true;event(row,"switch",vec(row.path[0]));return ""
 if part=="battery":
  if FrontierExplorationIncidents.carriers(world,actor):return "운반 중인 물건을 먼저 내려놓으세요."
  row.battery_carrier=actor;row.battery_carrier_rescue=int(world.crew.members[actor].get("vitals",{}).get("rescue_serial",0));event(row,"carry",p);return ""
 if part=="socket":
  if row.battery_carrier!=actor:return "배터리를 직접 운반해 연결하세요."
  row.battery_carrier="";row.battery_installed=true;event(row,"connect",p);return ""
 if part=="rover_toggle":m.running=not m.running;event(row,"switch",p);return ""
 if part=="cargo" or part.begins_with("crate_"):
  if FrontierExplorationIncidents.carriers(world,actor):return "운반 중인 물건을 먼저 내려놓으세요."
  if row.template=="aerial_sensor_recovery" and (float(m.observed)<float(cfg.observe_seconds) or not bird_away(row)):return "거리를 두고 관찰한 뒤 개체가 날아가면 회수하세요."
  if part.begins_with("crate_"):m.cargo_index=part.get_slice("_",1).to_int()
  row.carrier=actor;row.carrier_rescue=int(world.crew.members[actor].get("vitals",{}).get("rescue_serial",0));event(row,"carry",p);return ""
 if part=="delivery":
  if row.carrier!=actor:return "직접 운반한 화물을 인계하세요."
  if row.template=="freighter_rescue_chain":
   m.steps[int(m.cargo_index)]=1;m.cargo_index=-1;m.delivered+=1;row.carrier="";row.cargo_ground=[];event(row,"connect",p);return ""
  return finish(world,actor,row)
 if part=="finish":return finish(world,actor,row)
 return "현장 목표를 확인하세요."
static func finish(world: Dictionary,actor: String,row: Dictionary) -> String:
 var error:=FrontierExplorationIncidents.reward(world,actor,reward(row))
 if not error.is_empty():return error
 if row.template=="cliff_relay_run":row.mission.steps[3]=1
 row.claimed=true;row.carrier="";row.phase="recovered";event(row,"complete",vec(row.relay));return ""
static func drive_hit(row: Dictionary,damage: float) -> Dictionary:
 var before:=float(row.mission.drive_hp)
 row.mission.drive_hp=maxf(0,before-damage)
 if row.mission.drive_hp<=0:row.open=true;row.cargo_ground=arr(vec(row.mission.moving)+Vector3.UP*1.1)
 event(row,"stop" if row.open else "hit",vec(row.mission.moving))
 return {"damage":before-float(row.mission.drive_hp),"shield":0.0,"broken":false,"weak":true,"killed":row.open}
static func tick(world: Dictionary,row: Dictionary,delta: float,present: Array,f: FrontierTerrainField,obstacle: Callable) -> bool:
 var m: Dictionary=row.mission;var cfg:=rules(row);var changed:=false
 if row.template=="aerial_sensor_recovery" and float(m.observed)<float(cfg.observe_seconds):
  var bp:=bird_point(row)
  for actor in present:
   var p:=vec(world.crew.members[actor].position)+Vector3.UP*1.7
   if p.distance_to(bp)>8 and p.distance_to(bp)<35 and FrontierCrewSurface.visible_in_field(f,p,bp):m.observed=minf(float(cfg.observe_seconds),float(m.observed)+delta);changed=true;break
 if row.template in ["vent_field_extraction","freighter_rescue_chain"]:
  var period:=float(cfg.hazard_period)
  for i in m.anchors.size():
   if int(m.steps[i])>0:continue
   var offset: float=float(i)*period/m.anchors.size();var strike:=period-.8
   if floori((float(row.age)-delta+offset-strike)/period)==floori((float(row.age)+offset-strike)/period):continue
   var center:=vec(m.anchors[i]);m.hazard_serial+=1;event(row,"blast",center);changed=true
   for actor in present:
    var p:=vec(world.crew.members[actor].position)+Vector3.UP
    if p.distance_to(center)>float(cfg.hazard_radius) or not FrontierCrewSurface.visible_in_field(f,center+Vector3.UP,p):continue
    if obstacle.is_valid() and float(obstacle.call(actor,center+Vector3.UP,(p-center-Vector3.UP).normalized(),p.distance_to(center+Vector3.UP)))<p.distance_to(center+Vector3.UP)-.5:continue
    FrontierExplorationIncidents.hurt(world,actor,float(cfg.hazard_damage),"blast")
 if row.template in ["runaway_convoy_intercept","stranded_survey_rover"] and not row.open:
  var rover: bool=row.template=="stranded_survey_rover";var moving: Vector3=vec(m.moving)
  if rover:
   if not row.battery_installed or not m.running:return changed
   var nearby:=false
   for actor in present:
    if vec(world.crew.members[actor].position).distance_to(moving)<14:nearby=true;break
   if not nearby:return changed
  var total:=0.0
  for i in range(1,row.path.size()):total+=vec(row.path[i-1]).distance_to(vec(row.path[i]))
  var next_distance:=float(m.distance)+delta*float(cfg.vehicle_speed)*(.65 if rover else 1.0)
  if not rover and m.running and next_distance>=total:row.open=true;m.drive_hp=0;row.cargo_ground=arr(moving+Vector3.UP*1.1);event(row,"stop",moving);return true
  if rover:next_distance=minf(next_distance,total)
  else:next_distance=fposmod(next_distance,total)
  var remainder:=next_distance;var target:=moving
  for i in range(1,row.path.size()):
   var a:=vec(row.path[i-1]);var b:=vec(row.path[i]);var length:=a.distance_to(b)
   if remainder<=length:target=a.lerp(b,remainder/maxf(.01,length));break
   remainder-=length
  if rover:
   for i in m.anchors.size():
    if int(m.steps[i])<int(cfg.blocker_hits) and target.distance_to(vec(m.anchors[i]))<3:return changed
  var motion:=target-moving
  if motion.length()>.001:
   if obstacle.is_valid() and float(obstacle.call(present[0],moving+Vector3.UP*1.5,motion.normalized(),motion.length()+1.6))<motion.length()+1.3:return changed
   m.moving_yaw=atan2(-motion.x,-motion.z)
  m.distance=next_distance;m.moving=arr(target);changed=true
  if rover and next_distance>=total-.01:row.open=true;m.running=false;event(row,"connect",target)
 return changed
static func validate(row: Dictionary) -> bool:
 if not enabled(row):return true
 if row.get("mission_version")!=1 or not allowed(row.template,int(row.tier)) or not row.get("mission") is Dictionary:return false
 var m: Dictionary=row.mission
 for k in ["anchors","steps","angles"]:
  if not m.get(k) is Array:return false
 if m.anchors.is_empty() or m.anchors.size()>6 or m.steps.size()!=m.anchors.size() or m.angles.size()!=3:return false
 for p in m.anchors:
  if not FrontierUniverse._vector3_array(p):return false
 for v in m.steps:
  if not FrontierExpeditionBusiness.integer(v,0,5):return false
 for v in m.angles:
  if not FrontierUniverse._finite(v,0,TAU):return false
 for k in ["distance","observed","drive_hp","hazard_serial","delivered"]:
  if not FrontierUniverse._finite(m.get(k),0,9007199254740000):return false
 if not FrontierUniverse._vector3_array(m.get("moving")) or not FrontierUniverse._vector3_array(m.get("event_point")) or not m.get("running") is bool:return false
 if not FrontierUniverse._finite(m.get("moving_yaw"),-TAU,TAU) or not FrontierExpeditionBusiness.integer(m.get("cargo_index"),-1,m.steps.size()-1):return false
 if not m.get("event") is String or not m.get("rescue_id") is String:return false
 if row.template=="aerial_sensor_recovery":
  if not m.get("bird") is Dictionary or FrontierEcologyCatalog.form(str(m.bird.get("form_id",""))).is_empty():return false
 return true
