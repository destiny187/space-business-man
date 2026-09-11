extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func run() -> void:
	var forms:=FrontierEcologyCatalog.all_forms()
	var extra: Array=forms.filter(func(row):return row.get("collection","")=="xenoflora-100")
	check(forms.size()==1000 and extra.size()==100,"100 additional base forms; 1000 total")
	var categories: Dictionary={};var families: Dictionary={};var names: Dictionary={};var hashes: Dictionary={}
	for row in forms:categories[row.category]=int(categories.get(row.category,0))+1
	check(categories=={"animal":700,"plant":185,"microbe":115},"animal/plant/microbe catalogue totals")
	for row in extra:
		families[row.family]=true;names[row.name]=true;hashes[row.lods.near.sha256]=true
		check(FileAccess.file_exists("res://../"+row.source) and ResourceLoader.exists("res://"+str(row.lods.near.path).trim_prefix("우주-비즈니스/")) and ResourceLoader.exists("res://"+str(row.lods.far.path).trim_prefix("우주-비즈니스/")),row.id+" source/near/far")
		if row.category=="microbe":check(row.representation=="visible_microbial_colony","microbes represented as visible colonies")
	check(families.size()==20 and names.size()==100 and hashes.size()==100,"20 structure families, unique names and model files")
	check(FrontierEcologyCatalog.all_appearances().size()==20000,"20,000 appearance profiles counted separately")
	var old_cfg:=FrontierUniverse.config();old_cfg.ecology_rules.erase("flora_catalog_hash");old_cfg.ecology_rules.erase("non_animal_lineages_per_layer")
	var old_manifest:=FrontierUniverse.generate(71491,old_cfg)
	var old_ecology:=FrontierEcology.create()
	for ordinal in [8,11,15,24]:
		var body:=FrontierUniverse.body(old_manifest,ordinal,false)
		if not FrontierUniverse.landable(body):continue
		var record:=FrontierEcology.ensure_planet(old_ecology,body)
		check(record.lineages.all(func(row):return FrontierEcologyCatalog.form(row.form_id).get("collection","")!="xenoflora-100"),"900-form world retains previous selection pool")
	check(FrontierEcology.validate(JSON.parse_string(JSON.stringify(old_ecology)),old_manifest).is_empty(),"pre-flora saved ecology validates unchanged")
	var manifest:=FrontierUniverse.generate(71491);var ecology:=FrontierEcology.create();var fixtures: Dictionary={}
	for ordinal in range(8,512):
		var body:=FrontierUniverse.body(manifest,ordinal,false)
		if not FrontierUniverse.landable(body) or int(body.planet_tier)>2:continue
		var record:=FrontierEcology.ensure_planet(ecology,body)
		if record.profile.origin!="established":continue
		var field:=FrontierExplorationIncidents.field(body)
		for candidate in FrontierEcologyPlacement.candidates(body,record,Vector3(70,0,70)):
			var form:=FrontierEcologyCatalog.form(candidate.form_id)
			if form.get("collection","")!="xenoflora-100" or fixtures.has(form.category) or candidate.layer!="surface":continue
			var at:=FrontierEcologyPlacement.ground(field,candidate)
			if not at.is_finite() or FrontierEcology.status(record,form,at,"surface")!="active":continue
			candidate.point=at
			var fixture: Dictionary={"ordinal":ordinal,"body_id":body.id,"encounter":candidate.duplicate(true)}
			fixture.encounter.point=FrontierExpeditionBusiness.array(at);fixtures[form.category]=fixture
			FrontierEcology.scan(ecology,body.id,candidate);FrontierEcology.collect(ecology,body.id,candidate)
		if fixtures.size()==2:break
	check(fixtures.has("plant") and fixtures.has("microbe"),"both new categories naturally selected and ground-supported on T1/T2")
	check(ecology.specimens.size()==2,"both new categories produce distinct specimens")
	check(FrontierEcology.validate(JSON.parse_string(JSON.stringify(ecology)),manifest).is_empty(),"new species, scans and specimens validate after JSON roundtrip")
	DirAccess.make_dir_recursive_absolute("/tmp/xenoflora-play")
	FileAccess.open("/tmp/xenoflora-play/fixtures.json",FileAccess.WRITE).store_string(JSON.stringify(fixtures,"  "))
	var rules:=FrontierEcologyCatalog.expansion();var tiers: Array=[]
	for tier in range(1,6):
		var origin: Dictionary=rules.native_origin_by_tier[str(tier)];var layers: Dictionary={}
		for layer in ["surface","cave"]:
			var animals:=int(rules.animals_by_tier[str(tier)][layer]);var plants:=int(rules.non_animal_lineages_per_layer.plant);var microbes:=int(rules.non_animal_lineages_per_layer.microbe)
			var total:=float(animals+plants+microbes)
			layers[layer]={"lineages":{"animal":animals,"plant":plants,"microbe":microbes},"candidate_share_percent":{"animal":100*animals/total,"plant":100*plants/total,"microbe":100*microbes/total}}
		tiers.append({"tier":tier,"origin":origin,"before_climate_and_placement":{"animal_active_origin_weight":origin.established,"plant_including_dormant_origin_weight":100-origin.sterile,"microbe_including_dormant_origin_weight":100-origin.sterile},"layers":layers})
	var probability: Dictionary={"scope":"새 은하의 초기 기원 가중치. 휴면 동물은 숨기고 식물/미생물 휴면체는 표시한다. 기후·지형·거리·표시 상한을 적용한 실제 목격률과 구분한다. 배치 비중은 세 범주의 계통 풀이 모두 있을 때의 셀 후보 선택 비중.","tiers":tiers}
	FileAccess.open("res://../docs/production/media/xenoflora/probabilities.json",FileAccess.WRITE).store_string(JSON.stringify(probability,"  "))
	FileAccess.open("res://../docs/production/media/xenoflora/rules-check.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"categories":categories,"new_species":extra.size(),"fixtures":fixtures},"  "))
	print("XENOFLORA_RULES ",checks," failures=",failures," categories=",categories);quit(0 if failures.is_empty() else 1)
