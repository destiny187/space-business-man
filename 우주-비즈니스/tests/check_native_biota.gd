extends SceneTree
## Focused ownership/geography check. --recipe-fixture checks generation before art finishes.
var failures: Array[String]=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func run() -> void:
	var fixture: bool="--recipe-fixture" in OS.get_cmdline_user_args()
	FrontierEcologyCatalog.prepare()
	if fixture:
		for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/biota_recipes.json")).species:
			FrontierEcologyCatalog._forms[row.id]=row
			var id: String=row.id+"_p00_s00";FrontierEcologyCatalog._looks[row.id]={id:{"id":id,"form_id":row.id,"scale":1.0}}
		FrontierEcologyCatalog._biota_signature="recipe-fixture-not-art-validation"
	var before:=Time.get_ticks_msec();var m:=FrontierUniverse.generate(71491);var duration:=Time.get_ticks_msec()-before
	check(int(m.settings.planet_count)==500000,"new galaxy has 500,000 planet addresses")
	check(is_equal_approx((pow(float(m.settings.outer_radius),2)-pow(float(m.settings.inner_radius),2))/500000.0,(500.0*500.0-100.0*100.0)/1000000.0),"area per system preserved")
	var sun:=FrontierUniverse.map_position(m,0);check(sun.x>0 and absf(sun.y)<.001,"Sun east, center to the left")
	check(m.has("native_biota"),"complete deterministic native assignment exists")
	check(FrontierUniverse.fingerprint(m)==FrontierUniverse.fingerprint(JSON.parse_string(JSON.stringify(m,"",true,true))),"native manifest survives exact save JSON round trip")
	var seen: Dictionary={};var tiers: Dictionary={};var region: Dictionary={"coreward":0,"other":0};var new_unassigned: Array=[]
	for id in m.native_biota.planets:
		var record: Dictionary=m.native_biota.planets[id]
		var body:=FrontierUniverse.body(m,int(id),false);var t:=str(body.planet_tier)
		if not tiers.has(t):tiers[t]={"planets":0,"species":0,"active_origin":0}
		tiers[t].planets+=1;tiers[t].species+=record.lineages.size()
		if record.origin=="established":tiers[t].active_origin+=1
		region["coreward" if record.coreward else "other"]+=1
		for row in record.lineages:
			check(not seen.has(row.form_id),row.form_id+" has exactly one natural planet")
			seen[row.form_id]=id
	for id in m.native_biota.unassigned_species:
		if FrontierEcologyCatalog.form(id).get("collection","")=="biota-7000":new_unassigned.append(id)
	check(new_unassigned.is_empty(),"all 7,000 new species have a compatible unique home")
	check(FrontierNativeBiota.validate(m).is_empty(),"ownership, appearances and habitat validation")
	check_atmosphere(m)
	var records: Dictionary={"planets":{}}
	var ids: Array=m.native_biota.planets.keys();ids.sort()
	for id in ids.slice(0,12):
		var body:=FrontierUniverse.body(m,int(id),false);var record:=FrontierEcology.ensure_planet(records,body)
		check(record.lineages==m.native_biota.planets[id].lineages,"assigned lineages reach actual ecology")
	var reverse: Dictionary={"planets":{}};var backwards:=ids.slice(0,12);backwards.reverse()
	for id in backwards:FrontierEcology.ensure_planet(reverse,FrontierUniverse.body(m,int(id),false))
	check(FrontierUniverse.fingerprint(records)==FrontierUniverse.fingerprint(reverse),"visit order does not change species")
	var old_cfg:=FrontierUniverse.config();old_cfg.planet_count=1000000;old_cfg.outer_radius=500.0;old_cfg.inner_radius=100.0;old_cfg.erase("galaxy_layout");old_cfg.ecology_rules.erase("native_biota");old_cfg.ecology_rules.erase("biota_catalog_hash")
	var old:=FrontierUniverse.generate(71491,old_cfg);check(not old.has("native_biota") and old.settings.planet_count==1000000,"legacy galaxy retains 1,000,000 addresses and previous selection")
	check_legacy_save(old)
	var result: Dictionary={"checks":checks,"failures":failures,"recipe_fixture":fixture,"generation_ms":duration,"assigned":seen.size(),"unassigned_new":new_unassigned,"unassigned_old":m.native_biota.unassigned_species.size()-new_unassigned.size(),"tiers":tiers,"region":region,"inspected_systems":m.native_biota.inspected_systems}
	DirAccess.make_dir_recursive_absolute("res://../docs/production/media/biota")
	FileAccess.open("res://../docs/production/media/biota/ownership-check.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	FileAccess.open("/tmp/biota-native-manifest.json",FileAccess.WRITE).store_string(JSON.stringify(m))
	print("NATIVE_BIOTA ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)

func check_legacy_save(m: Dictionary) -> void:
	# A separate fixture exercises an address removed from NEW galaxies. Never
	# open or migrate the player's real save while checking compatibility.
	var target:=750001
	while not FrontierUniverse.landable(FrontierUniverse.body(m,target)):target+=1
	var body:=FrontierUniverse.body(m,target);var ecology:=FrontierEcology.create()
	FrontierEcology.ensure_planet(ecology,body)
	var value: Dictionary={"version":2,"expedition_research":FrontierExpeditionResearch.create(),"manifest":m,"manifest_hash":FrontierUniverse.fingerprint(m),"visited":{body.id:true},"terrain_edits":{},"location":body.id,"flight_position":[0,0,0],"ecology":ecology}
	var store:=FrontierWorldStore.new("/tmp/biota-legacy-million-world.json")
	check(store.write(value),"legacy million-planet save writes with its original rules: "+store.last_error)
	var restored:=store.read_state()
	check(not restored.is_empty() and restored.location==body.id and restored.manifest.settings.planet_count==1000000 and not restored.manifest.has("native_biota") and FrontierUniverse.fingerprint(restored.ecology)==FrontierUniverse.fingerprint(ecology),"legacy planet beyond 500,000 and its original species survive save/reload")

func check_atmosphere(m: Dictionary) -> void:
	var gas: Dictionary={}
	for id in m.native_biota.planets:
		var body:=FrontierUniverse.body(m,int(id),false)
		if body.kind in ["gas_giant","ice_giant"] and body.native_ecology.origin=="established":gas=body;break
	check(not gas.is_empty(),"a populated atmospheric home planet exists")
	if gas.is_empty():return
	var center:=FrontierUniverse.position(m,int(gas.ordinal),0)
	var position:=center+Vector3.BACK*(FrontierUniverse.navigation_radius(gas)+500)
	var nav: Dictionary={"system":FrontierUniverse.system_index(m,int(gas.ordinal)),"mode":"idle","orbit_time":0.0,"position":FrontierExpeditionBusiness.array(position)}
	var authority:=FrontierCrewAuthority.new();authority.world={"manifest":m,"crew":{"navigation":nav,"revision":0},"ecology":FrontierEcology.create()}
	var saved: Dictionary={};authority.save_world=func(draft):saved.value=draft.duplicate(true);return true
	authority.inputs[1]={"aim":Vector3.FORWARD}
	check(FrontierAtmosphereSurvey.target(m,nav,Vector3.BACK).is_empty(),"looking away does not observe gas life")
	check(FrontierAtmosphereSurvey.step(authority,1,authority.world,.1),"held orbital scan targets nearby atmosphere")
	check(authority.world.ecology.observations.is_empty() and float(authority.scans[1].progress)<1,"no early discovery before scan completes")
	for i in 31:FrontierAtmosphereSurvey.step(authority,1,authority.world,.1)
	check(saved.has("value") and authority.world.ecology.observations.size()==1 and authority.scans[1].known,"persisted atmospheric observation reaches confirmed result")
	for i in 35:FrontierAtmosphereSurvey.step(authority,1,authority.world,.1)
	check(authority.world.ecology.observations.size()==1,"continued hold retains observed creature until release")
	check(FrontierEcology.validate(authority.world.ecology,m).is_empty(),"atmosphere observation and natural home survive save validation")
	var failed:=FrontierCrewAuthority.new();failed.world={"manifest":m,"crew":{"navigation":nav,"revision":0},"ecology":FrontierEcology.create()};failed.inputs[1]={"aim":Vector3.FORWARD};failed.save_world=func(_draft):return false
	FrontierAtmosphereSurvey.step(failed,1,failed.world,4)
	check(failed.stopped and failed.world.ecology.observations.is_empty() and not failed.scans.has(1),"failed save gives no confirmed observation")
