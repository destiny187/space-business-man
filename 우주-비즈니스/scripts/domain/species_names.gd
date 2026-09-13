class_name FrontierSpeciesNames
extends RefCounted
## World-owned discovery identities. Catalogue names remain private production labels.
const PREFIXES: Dictionary={"animal":"ANI","plant":"PLT","microbe":"MIC"}
const MAX_NAME:=32
static func ensure(ecology: Dictionary) -> void:
	if not ecology.has("species_names"):ecology.species_names={}
	if not ecology.has("naming_revision"):ecology.naming_revision=0
	# Legacy observations have no discovery timestamp. Preserve their stored order.
	for row in ecology.get("observations",{}).values():register(ecology,str(row.form_id))
static func register(ecology: Dictionary,form_id: String) -> void:
	if not ecology.has("species_names"):ecology.species_names={}
	if ecology.species_names.has(form_id):return
	var prefix: String=PREFIXES.get(FrontierEcologyCatalog.form(form_id).get("category",""),"")
	if prefix.is_empty():return
	var next:=1
	for row in ecology.species_names.values():
		if str(row.code).begins_with(prefix+"-"):next=maxi(next,int(str(row.code).get_slice("-",1))+1)
	ecology.species_names[form_id]={"code":"%s-%03d"%[prefix,next],"name":""}
	ecology.naming_revision=int(ecology.get("naming_revision",0))+1
static func identity(ecology: Dictionary,form_id: String) -> Dictionary:
	return ecology.get("species_names",{}).get(form_id,{})
static func display(ecology: Dictionary,form_id: String) -> String:
	var row:=identity(ecology,form_id)
	return str(row.name) if not str(row.get("name","")).is_empty() else str(row.get("code","미등록 생물"))
static func name_error(value: Variant) -> String:
	if not value is String:return "이름 형식이 올바르지 않습니다."
	if value.length()>MAX_NAME:return "이름은 %d자까지 입력할 수 있습니다."%MAX_NAME
	for i in value.length():
		var c: int=value.unicode_at(i)
		if c<32 or (c>=127 and c<=159) or c in [0x2028,0x2029]:return "이름에는 줄바꿈이나 제어 문자를 사용할 수 없습니다."
	return ""
static func rename(ecology: Dictionary,args: Dictionary) -> String:
	if not args.get("form_id") is String:return "발견한 생물을 선택하세요."
	var row:=identity(ecology,args.form_id)
	if row.is_empty():return "먼저 생물을 스캔해 도감에 등록하세요."
	var reason:=name_error(args.get("name"))
	if not reason.is_empty():return reason
	if args.get("previous_name")!=row.name:return "다른 승무원이 이름을 변경했습니다. 도감에서 최신 이름을 확인하세요."
	var name: String=args.name.strip_edges()
	if name==row.name:return ""
	row.name=name;ecology.naming_revision=int(ecology.get("naming_revision",0))+1
	return ""
static func validate(ecology: Dictionary) -> String:
	if not ecology.has("species_names"):return "" # Legacy save, migrated after validation.
	var names: Variant=ecology.species_names
	if not names is Dictionary or not FrontierExpeditionBusiness.integer(ecology.get("naming_revision"),0,9007199254740000):return "생물 이름 기록 형식 오류"
	var observed: Dictionary={};var codes: Dictionary={}
	for row in ecology.observations.values():observed[row.form_id]=true
	if names.size()!=observed.size():return "생물 이름과 발견 기록의 수가 다릅니다."
	for id in names:
		var row: Variant=names[id]
		if not observed.has(id) or not row is Dictionary or not row.get("code") is String:return "발견되지 않은 생물의 이름 기록"
		if not name_error(row.get("name")).is_empty() or row.name!=row.name.strip_edges():return "저장된 생물 이름 형식 오류"
		var code: String=row.code;var prefix: String=PREFIXES.get(FrontierEcologyCatalog.form(id).category,"")
		var serial:=code.get_slice("-",1)
		if not serial.is_valid_int() or int(serial)<1 or code!="%s-%03d"%[prefix,int(serial)] or codes.has(code):return "생물 발견 번호가 잘못됐거나 중복됐습니다."
		codes[code]=true
	return ""
static func for_view(world: Dictionary,actor: String) -> Dictionary:
	var local:=FrontierShuttles.context(world,actor)
	var ecology: Dictionary=world.ecology;var forms: Dictionary={};var result: Dictionary={}
	var planet: Dictionary=ecology.planets.get(local.location,{})
	for rows in [planet.get("lineages",[]),planet.get("introductions",{}).values(),ecology.research.values()]:
		for row in rows:forms[row.form_id]=true
	var stocks: Array=[FrontierExpeditionBusiness.bag(world,actor),local.crew.get("cargo",{})]
	stocks.append(world.get("business",{}).get("sites",{}).get(local.location,{}).get("inventory",{}))
	for vehicle in world.get("rovers",{}).get("vehicles",{}).values():
		if vehicle.get("body_id","")==local.location:stocks.append(vehicle.get("cargo",{}))
	for stock in stocks:
		for sample in FrontierSpecimenItems.carried(stock).values():forms[sample.form_id]=true
	for id in forms:
		if ecology.get("species_names",{}).has(id):result[id]=ecology.species_names[id].duplicate()
	return result
