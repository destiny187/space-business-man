extends SceneTree
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func run() -> void:
	var forms:=FrontierEcologyCatalog.all_forms()
	var extra: Array=forms.filter(func(row):return row.get("collection","")=="xenofauna-300")
	check(extra.size()==300,"300 additional base animal models")
	check(forms.filter(func(row):return row.category=="animal").size()==700,"700 total animal base models")
	var meshes: Dictionary={};var names: Dictionary={};var families: Dictionary={}
	for row in extra:
		meshes[row.lods.near.sha256]=true;names[row.name]=true;families[row.family]=true
		check(FileAccess.file_exists("res://../"+row.source) and ResourceLoader.exists("res://"+str(row.lods.near.path).trim_prefix("우주-비즈니스/")) and ResourceLoader.exists("res://"+str(row.lods.far.path).trim_prefix("우주-비즈니스/")),row.id+" editable source and both game LODs")
	check(meshes.size()==300 and names.size()==300 and families.size()==30,"unique base geometry, names and 30 new body plans")
	check(FrontierEcologyCatalog.all_appearances().size()==forms.size()*20,"appearance profiles counted separately")
	var cfg:=FrontierUniverse.config();cfg.erase("ecology_rules")
	var old_manifest:=FrontierUniverse.generate(71491,cfg)
	var old_body:=FrontierUniverse.body(old_manifest,8,false)
	var old_ecology:=FrontierEcology.create();var old_record:=FrontierEcology.ensure_planet(old_ecology,old_body)
	var frozen:=JSON.stringify(old_record)
	var legacy_animals: Array=old_record.lineages.filter(func(row):return FrontierEcologyCatalog.form(row.form_id).category=="animal" and FrontierEcologyCatalog.form(row.form_id).environment!="cave")
	check(not legacy_animals.is_empty(),"legacy natural T1 reproduction has native animal ancestry")
	if not legacy_animals.is_empty():check(FrontierEcology.status(old_record,FrontierEcologyCatalog.form(legacy_animals[0].form_id),Vector3(100,0,100),"surface")=="active","bar/kPa bug fixed at climate boundary")
	check(JSON.stringify(old_record)==frozen and old_record.lineages.all(func(row):return FrontierEcologyCatalog.form(row.form_id).get("collection","")!="xenofauna-300"),"old saved profile and original ancestry untouched")
	check(FrontierEcology.validate(JSON.parse_string(JSON.stringify(old_ecology)),old_manifest).is_empty(),"old ecology JSON remains valid")
	var manifest:=FrontierUniverse.generate(71491)
	var ecology:=FrontierEcology.create();var eligible: Dictionary={};var encounter: Dictionary={}
	for ordinal in range(8,264):
		var body:=FrontierUniverse.body(manifest,ordinal,false)
		if not FrontierUniverse.landable(body) or int(body.planet_tier)>2:continue
		var record:=FrontierEcology.ensure_planet(ecology,body)
		if record.profile.origin!="established":continue
		var field:=FrontierExplorationIncidents.field(body)
		for candidate in FrontierEcologyPlacement.candidates(body,record,Vector3(70,0,70)):
			var form:=FrontierEcologyCatalog.form(candidate.form_id)
			if form.get("collection","")!="xenofauna-300" or candidate.layer!="surface":continue
			var at:=FrontierEcologyPlacement.ground(field,candidate)
			if not at.is_finite() or FrontierEcology.status(record,form,at,"surface")!="active":continue
			candidate.point=at;eligible=body;encounter=candidate;break
		if not eligible.is_empty():break
	check(not eligible.is_empty(),"new species naturally selected and physically placed on a T1/T2 planet")
	if not eligible.is_empty():
		var record: Dictionary=ecology.planets[eligible.id]
		check(record.lineages==FrontierEcology.ensure_planet({"planets":{}},eligible).lineages,"seeded expanded ancestry stable")
		var surface_animals: Array=record.lineages.filter(func(row):return FrontierEcologyCatalog.form(row.form_id).category=="animal" and FrontierEcologyCatalog.form(row.form_id).environment!="cave")
		var distinct: Dictionary={}
		for row in surface_animals:distinct[FrontierEcologyCatalog.form(row.form_id).family]=true
		check(distinct.size()==surface_animals.size(),"different silhouettes chosen before repeating a family")
		FrontierEcology.scan(ecology,eligible.id,encounter);FrontierEcology.collect(ecology,eligible.id,encounter)
		check(ecology.specimens.size()==1,"new species scan and unique physical specimen")
		FrontierEcology.collect(ecology,eligible.id,encounter)
		check(ecology.specimens.size()==1,"repeated specimen request cannot duplicate")
		check(FrontierEcology.validate(JSON.parse_string(JSON.stringify(ecology)),manifest).is_empty(),"expanded ancestry, observations and specimen survive JSON validation")
		DirAccess.make_dir_recursive_absolute("/tmp/xenofauna-play")
		var fixture: Dictionary={"ordinal":eligible.ordinal,"body_id":eligible.id,"encounter":encounter.duplicate(true)}
		fixture.encounter.point=FrontierExpeditionBusiness.array(encounter.point)
		FileAccess.open("/tmp/xenofauna-play/fixture.json",FileAccess.WRITE).store_string(JSON.stringify(fixture,"  "))
	var origin_rules: Dictionary=FrontierEcologyCatalog.expansion().native_origin_by_tier
	for tier in range(1,6):
		var r: Dictionary=origin_rules[str(tier)]
		check(int(r.sterile)>0 and int(r.sterile)+int(r.dormant)+int(r.established)==100,"sterile worlds retained at T"+str(tier))
		if tier>1:check(int(r.established)>int(origin_rules[str(tier-1)].established),"established weight rises with tier")
	var output: Dictionary={"checks":checks,"failures":failures,"new_species":extra.size(),"animal_total":700,"new_body_plans":families.size(),"native_fixture":eligible.get("ordinal",-1),"origin_rules":origin_rules}
	FileAccess.open("res://../docs/production/media/xenofauna/rules-check.json",FileAccess.WRITE).store_string(JSON.stringify(output,"  "))
	print("XENO_RULES ",JSON.stringify(output));quit(0 if failures.is_empty() else 1)
