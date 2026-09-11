extends RefCounted
## Species identity, not look/scale, selects a reproducible field function.
static var cached: Dictionary={}
static var definitions: Dictionary={}
static func config() -> Dictionary:
 if cached.is_empty():cached=JSON.parse_string(FileAccess.get_file_as_string("res://data/species_functions.json"))
 return cached
static func definition(form: Dictionary) -> Dictionary:
 if definitions.has(form.get("id","")):return definitions[form.id]
 var choices: Array=config().categories.get(form.get("category",""),[])
 if choices.is_empty() or not FrontierEcologyCatalog.ground_form(form):return {}
 var seed_value:=str(form.id).sha256_text().substr(0,8).hex_to_int()
 var key: String=choices[seed_value%choices.size()]
 var result: Dictionary=config().roles[key].duplicate()
 result.id=key;result.bonus=float(config().strengths[(seed_value/choices.size())%config().strengths.size()])
 definitions[form.id]=result
 return result
static func studied(ecology: Dictionary,form_id: String) -> bool:
 return ecology.get("species_research",{}).has(form_id)
static func study(world: Dictionary,actor: String,form_id: String) -> String:
 var ecology: Dictionary=world.ecology
 var form:=FrontierEcologyCatalog.form(form_id)
 if form.is_empty() or definition(form).is_empty():return "이 종은 지상 복원 기능 분석 대상이 아닙니다."
 if studied(ecology,form_id):return "이 종의 기능 분석은 완료했습니다."
 if not ecology.research.has(form.environment):return "먼저 서식 환경의 기초 분석을 완료하세요."
 var sample_id:=""
 for id in ecology.specimens:
  var sample: Dictionary=ecology.specimens[id]
  if sample.form_id==form_id and sample.state=="cargo" and FrontierSpecimenItems.owns(world,actor,sample):sample_id=id;break
 if sample_id.is_empty():return "분석할 이 종의 실물 표본을 내 아이템창으로 가져오세요."
 var cost: int=int(config().study_rock_cost)
 if int(world.crew.rock)<cost:return "실험용 광물 %d개가 착륙지 창고에 필요합니다."%cost
 if not ecology.has("species_research"):ecology.species_research={}
 ecology.species_research[form_id]=sample_id
 world.crew.rock-=cost
 return ""
static func validate(ecology: Dictionary) -> String:
 var studies: Variant=ecology.get("species_research",{})
 if not studies is Dictionary:return "종별 기능 연구 형식 오류"
 for id in studies:
  if not id is String or not studies[id] is String:return "종별 기능 연구 식별 오류"
  var form:=FrontierEcologyCatalog.form(id)
  var sample: Dictionary=ecology.specimens.get(studies[id],{})
  if form.is_empty() or definition(form).is_empty() or sample.get("form_id")!=id or not ecology.research.has(form.environment):return "실물 표본의 근거가 없는 기능 연구"
 return ""
static func support(world: Dictionary,b: Dictionary) -> Dictionary:
 var ecology: Dictionary=world.get("ecology",{})
 var record: Dictionary=ecology.get("planets",{}).get(world.get("location",""),{})
 var plot: Dictionary=record.get("plot",{})
 if plot.is_empty() or float(plot.support_remaining)<=0:return {}
 var point:=FrontierCrewWorld.vector(b.get("position",[]))
 if not point.is_finite() or point.distance_to(FrontierCrewWorld.vector(plot.center))>float(FrontierEcologyCatalog.config().plot_radius):return {}
 var best: Dictionary={}
 for row in record.get("introductions",{}).values():
  if not studied(ecology,row.form_id):continue
  var form:=FrontierEcologyCatalog.form(row.form_id);var function:=definition(form)
  if function.get("building")!=b.get("type"):continue
  var origin:=FrontierCrewWorld.vector(row.position)
  if point.distance_to(origin)>float(config().facility_radius):continue
  var climate:=FrontierEcology.climate_at(record,origin,row.layer)
  if not climate.get("restored",false) or not FrontierEcology.unsuitable(form,climate,row.layer).is_empty():continue
  if best.is_empty() or float(function.bonus)>float(best.bonus):
   best=function.duplicate();best.form_id=row.form_id;best.sample_id=row.id
 return best
static func factor(world: Dictionary,b: Dictionary) -> float:
 return 1.0+float(support(world,b).get("bonus",0.0))
