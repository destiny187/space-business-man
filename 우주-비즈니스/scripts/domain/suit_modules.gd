class_name FrontierSuitModules
extends RefCounted
## Individual, host-rolled module instances; never changes the suit appearance.
static var _config: Dictionary={}
static func config() -> Dictionary:
 if _config.is_empty():_config=JSON.parse_string(FileAccess.get_file_as_string("res://data/suit_modules.json"))
 return _config
static func create() -> Dictionary:return {"version":1,"items":{},"equipped":{},"starter":false,"revision":0}
static func state(member: Dictionary) -> Dictionary:return member.get("modules",{})
static func ensure(member: Dictionary) -> void:
 if not member.has("modules"):member.modules=create()
static func roll(seed_value: int,tier: int,source: String) -> Dictionary:
 tier=clampi(tier,1,3)
 var rng:=RandomNumberGenerator.new();rng.seed=seed_value
 var pool: Array=config().drops.get(source,config().drops.discovery)
 var slot: String=pool[rng.randi_range(0,pool.size()-1)]
 var chance:=rng.randi_range(1,100);var rarity: String="common"
 var names: Array=config().rarities.keys();var weights: Array=config().rarity_weights[str(tier)]
 for i in names.size():
  chance-=int(weights[i])
  if chance<=0:rarity=names[i];break
 var d: Dictionary=config().slots[slot];var choices: Array=d.pool.duplicate()
 for stat in config().common_affixes:
  if stat not in choices:choices.append(stat)
 var affixes: Dictionary={}
 for i in int(config().rarities[rarity].affixes):
  var index:=rng.randi_range(0,choices.size()-1);var stat: String=choices[index];choices.remove_at(index)
  var rule: Dictionary=config().stats[stat];var amount:=rng.randf_range(float(rule.minimum),float(rule.maximum))*tier
  affixes[stat]=roundf(amount) if rule.unit=="flat" else snappedf(amount,.001)
 var result: Dictionary={"slot":slot,"tier":tier,"rarity":rarity,"affixes":affixes,"seed":seed_value,"source":source}
 if rarity=="legendary":
  var special: Array=[]
  for id in config().legendary:
   if slot in config().legendary[id].slots:special.append(id)
  result.legendary=special[rng.randi_range(0,special.size()-1)]
 return result
static func stats(item: Dictionary) -> Dictionary:
 if item.is_empty():return {}
 var d: Dictionary=config().slots[item.slot];var result: Dictionary=item.affixes.duplicate()
 result[d.stat]=float(result.get(d.stat,0))+float(d.base[int(item.tier)-1]);return result
static func bonus(member: Dictionary,stat: String) -> float:
 var rack:=state(member);var total:=0.0
 for id in rack.get("equipped",{}).values():total+=float(stats(rack.get("items",{}).get(id,{})).get(stat,0))
 return minf(total,float(config().stats[stat].cap))
static func factor(member: Dictionary,stat: String) -> float:
 var extra:=0.0
 if stat=="mobility" and has_effect(member,"break_dash") and float(member.get("vitals",{}).get("shield_haste",0))>0:extra=float(config().legendary.break_dash.factor)
 return 1.0+bonus(member,stat)+extra
static func shield_max(member: Dictionary) -> float:
 if not state(member).get("equipped",{}).has("defense"):return 0.0
 # The generator's base is not constrained by the affix-only cap.
 var rack:=state(member);var item: Dictionary=rack.items[rack.equipped.defense]
 var base:=float(config().slots.defense.base[int(item.tier)-1]);var extra:=0.0
 for id in rack.equipped.values():extra+=float(rack.items[id].affixes.get("shield",0))
 return base+minf(extra,float(config().stats.shield.cap))
static func shield_delay(member: Dictionary) -> float:
 var factor:=1.0
 if has_effect(member,"critical_recharge") and float(member.get("vitals",{}).get("health",100))<=FrontierCrewAugmentation.maximum_health(member)*float(config().legendary.critical_recharge.threshold):factor=float(config().legendary.critical_recharge.factor)
 return float(config().shield.delay)*(1.0-bonus(member,"shield_delay"))*factor
static func title(item: Dictionary) -> String:return "T%d %s %s"%[int(item.tier),config().rarities[item.rarity].name,config().slots[item.slot].name]
static func value_text(stat: String,value: float) -> String:
 return "%s %+.0f"%[config().stats[stat].name,value] if config().stats[stat].unit=="flat" else "%s %+.1f%%"%[config().stats[stat].name,value*100]
static func drop(world: Dictionary,actor: String,source_id: String,tier: int,source: String) -> String:
 var member: Dictionary=world.crew.members[actor];ensure(member);var rack: Dictionary=member.modules
 var id: String="module:"+source_id.sha256_text().substr(0,24)
 if rack.items.has(id):return "이미 회수한 모듈입니다."
 if rack.items.size()>=int(config().case_capacity):return "모듈 케이스가 가득 찼습니다. I → 모듈에서 정리하세요. 보상은 현장에 남습니다."
 var seed_value:=FrontierUniverse.derive(int(world.manifest.seed),source_id)
 rack.items[id]=roll(seed_value,tier,source);rack.revision+=1;return ""
static func apply(world: Dictionary,actor: String,args: Dictionary) -> String:
 var member: Dictionary=world.crew.members[actor];ensure(member);var rack: Dictionary=member.modules
 if args.size()!=3 or not FrontierExpeditionBusiness.integer(args.get("revision"),0,9007199254740991):return "모듈 요청 형식 오류"
 if int(args.revision)!=int(rack.revision):return "장비가 바뀌었습니다. 현재 목록에서 다시 선택하세요."
 var action: String=str(args.get("action",""));var id: String=str(args.get("id",""))
 if action=="starter":
  if rack.starter:return "기초 실드 발생기를 이미 조립했습니다."
  if rack.items.size()>=int(config().case_capacity):return "모듈 케이스가 가득 찼습니다."
  if not FrontierExpeditionBusiness.affordable(FrontierExpeditionBusiness.bag(world,actor),config().starter_cost):return "철 6개·구리 4개가 필요합니다."
  FrontierItemInventory.merge_legacy(world,actor)
  FrontierExpeditionBusiness.transfer(world.business.bags[actor],config().starter_cost,-1)
  rack.items["module:starter"]={"slot":"defense","tier":1,"rarity":"common","affixes":{},"seed":0,"source":"starter"};rack.starter=true
 else:
  if not rack.items.has(id):return "내가 소유한 모듈을 선택하세요."
  var item: Dictionary=rack.items[id];var slot: String=item.slot
  if action=="equip":
   if rack.equipped.get(slot,"")==id:return "이미 장착한 모듈입니다."
   var proposed:=member.duplicate(true);proposed.modules.equipped[slot]=id
   if not capacity_fits(world,actor,proposed):return "작은 가방으로 교체할 공간이 부족합니다. 자원을 먼저 보관하세요."
   rack.equipped[slot]=id;reconcile(member,slot=="defense")
  elif action=="unequip":
   if rack.equipped.get(slot,"")!=id:return "장착한 모듈을 선택하세요."
   var proposed:=member.duplicate(true);proposed.modules.equipped.erase(slot)
   if not capacity_fits(world,actor,proposed):return "가방 해제 후 수납 공간이 부족합니다. 자원을 먼저 보관하세요."
   rack.equipped.erase(slot);reconcile(member,slot=="defense")
  elif action=="salvage":
   if id in rack.equipped.values():return "장착 중인 모듈은 분해할 수 없습니다."
   var reward: Dictionary={"refined_iron":int(item.tier)}
   if not FrontierItemInventory.fits(world,actor,reward):return "분해 부품을 받을 배낭 공간이 부족합니다."
   if not world.business.bags.has(actor):world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
   FrontierExpeditionBusiness.transfer(world.business.bags[actor],reward,1);rack.items.erase(id)
  else:return "지원하지 않는 모듈 작업입니다."
 rack.revision+=1;return ""
static func capacity_fits(world: Dictionary,actor: String,proposed: Dictionary) -> bool:
 var bag:=FrontierExpeditionBusiness.bag(world,actor).duplicate();bag.stone=int(bag.get("stone",0))+int(world.crew.members[actor].carried)
 return FrontierItemInventory.used(bag,FrontierEquipment.state(proposed).items.size())<=FrontierItemInventory.capacity(proposed)
static func reconcile(member: Dictionary,reset_delay: bool=false) -> void:
 var v:=FrontierCrewVitals.ensure(member)
 v.health=minf(v.health,FrontierCrewAugmentation.maximum_health(member));v.shield=minf(v.shield,shield_max(member))
 if reset_delay:v.shield_wait=maxf(v.shield_wait,shield_delay(member))
 v.combat_wait=maxf(v.combat_wait,float(config().legendary.field_regeneration.delay))
 if not has_effect(member,"break_dash"):v.shield_haste=0.0
static func validate(value: Variant) -> bool:
 if not value is Dictionary or value.get("version")!=1 or not value.get("items") is Dictionary or value.items.size()>int(config().case_capacity) or not value.get("equipped") is Dictionary or not value.get("starter") is bool:return false
 if not FrontierExpeditionBusiness.integer(value.get("revision"),0,9007199254740991):return false
 for id in value.items:
  var item: Variant=value.items[id]
  if not id is String or not id.begins_with("module:") or id.length()>100 or not item is Dictionary:return false
  if not config().slots.has(item.get("slot")) or not config().rarities.has(item.get("rarity")) or not FrontierExpeditionBusiness.integer(item.get("tier"),1,3) or not item.get("affixes") is Dictionary:return false
  if not FrontierUniverse._finite(item.get("seed"),0,9223372036854775807) or not item.get("source") is String:return false
  if item.affixes.size()!=int(config().rarities[item.rarity].affixes):return false
  if item.rarity=="legendary":
   if not item.get("legendary") is String or not config().legendary.has(item.legendary) or item.slot not in config().legendary[item.legendary].slots:return false
  elif item.has("legendary"):return false
  var allowed: Array=config().slots[item.slot].pool+config().common_affixes
  for stat in item.affixes:
   if stat not in allowed:return false
   var rule: Dictionary=config().stats[stat];var upper:=ceilf(float(rule.maximum)*int(item.tier)) if rule.unit=="flat" else float(rule.maximum)*int(item.tier)+.001
   if not FrontierUniverse._finite(item.affixes[stat],0,upper):return false
 for slot in value.equipped:
  var id: Variant=value.equipped[slot]
  if not config().slots.has(slot) or not id is String or not value.items.has(id) or value.items[id].slot!=slot:return false
 return true

static func has_effect(member: Dictionary,effect: String) -> bool:
 var rack:=state(member)
 for id in rack.get("equipped",{}).values():
  var item: Dictionary=rack.get("items",{}).get(id,{})
  if item.get("rarity")=="legendary" and item.get("legendary")==effect:return true
 return false
static func effect_text(item: Dictionary) -> String:
 var d: Dictionary=config().legendary.get(str(item.get("legendary","")),{})
 return "" if d.is_empty() else str(d.name)+" · "+str(d.description)
static func shield_multiplier(member: Dictionary) -> float:return float(config().legendary.shield_breaker.factor) if has_effect(member,"shield_breaker") else 1.0
static func enter_combat(member: Dictionary) -> void:
 FrontierCrewVitals.ensure(member).combat_wait=float(config().legendary.field_regeneration.delay)
static func on_analysis(member: Dictionary) -> void:
 if not has_effect(member,"survey_charge"):return
 var v:=FrontierCrewVitals.ensure(member)
 var restored:=minf(shield_max(member)-float(v.shield),shield_max(member)*float(config().legendary.survey_charge.fraction))
 if restored>0:v.shield+=restored;v.legendary_serial+=1;v.legendary_effect="survey_charge"

static func on_kill(member: Dictionary) -> void:
 if not has_effect(member,"kill_recovery"):return
 var v:=FrontierCrewVitals.ensure(member);var d: Dictionary=config().legendary.kill_recovery
 FrontierCrewVitals.heal(member,FrontierCrewAugmentation.maximum_health(member)*float(d.health))
 v.stamina=minf(float(FrontierCrewVitals.config().maximum_stamina),float(v.stamina)+float(d.stamina));v.legendary_serial+=1;v.legendary_effect="kill_recovery"
static func full_shield_factor(member: Dictionary) -> float:
 return float(config().legendary.full_shield_power.factor) if has_effect(member,"full_shield_power") and shield_max(member)>0 and float(member.get("vitals",{}).get("shield",0))>=shield_max(member)-.001 else 1.0
