extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition:failures+=1;printerr("FAIL: "+message)
func run() -> void:
	var world:=FrontierUniverse.new_world(71491)
	var legacy:=world.duplicate(true)
	world.ecology=FrontierEcology.create()
	var ecology: Dictionary=world.ecology
	var source: Dictionary={}
	var destination: Dictionary={}
	var sterile: Dictionary={}
	var origins: Dictionary={}
	for i in 120:
		var body:=FrontierUniverse.body(world.manifest,i)
		var p:=FrontierEcology.profile(body)
		origins[p.origin]=true
		if body.kind=="basalt" and p.origin=="established" and p.temperature>=-12:
			if source.is_empty():source=body
			elif destination.is_empty():destination=body
		if p.origin=="sterile" and body.kind=="basalt":sterile=body
	check(origins.size()==3,"seeded origin includes sterile, dormant and established worlds")
	check(not source.is_empty() and not destination.is_empty(),"same substrate planets can have distinct ecology seeds")
	var record:=FrontierEcology.ensure_planet(ecology,source)
	var target:=FrontierEcology.ensure_planet(ecology,destination)
	var empty:=FrontierEcology.ensure_planet(ecology,sterile)
	check(record.lineages==FrontierEcology.ensure_planet({"planets":{}},source).lineages,"lineage and appearance remain deterministic across visits")
	check(record.lineages!=target.lineages,"different planet seeds choose distinct authored lineages")
	check(record.lineages.size()<=8 and ecology.planets.size()==3,"million addresses allocate only visited ecology records")
	check(FrontierUniverse.validate_world(legacy).is_empty(),"old world without ecology remains compatible")
	check(FrontierUniverse.validate_world(world).is_empty(),"new sparse ecology validates")
	check(FrontierUniverse.validate_world(JSON.parse_string(JSON.stringify(world))).is_empty(),"ecology survives JSON numeric round trip")
	var field:=FrontierTerrainField.new();field.configure(int(source.streams.terrain))
	var candidates:=FrontierEcologyPlacement.candidates(source,record,Vector3.ZERO)
	check(not candidates.is_empty(),"real surface/cave candidates exist near landing region")
	var observed: Dictionary={}
	var placed: Array[Dictionary]=[]
	for row in candidates:
		var p:=FrontierEcologyPlacement.ground(field,row)
		if p.is_finite():
			row.point=p;placed.append(row)
			var form:=FrontierEcologyCatalog.form(row.form_id)
			check(form.environment in ["basalt","cave"] and form.family not in ["ray","swimmer","winged","aquatic_frond","lantern_sail"],"dry ground excludes aquatic and unimplemented flying locomotion")
			if form.environment=="basalt":observed=row
	check(not observed.is_empty(),"ground support and body clearance find an actual surface specimen")
	if observed.is_empty():quit(1);return
	var form:=FrontierEcologyCatalog.form(observed.form_id)
	check(FrontierEcology.status(record,form,observed.point,"surface")=="active","established suitable substrate supports native life")
	check(FrontierEcologyPlacement.candidates(sterile,empty,Vector3.ZERO).is_empty(),"sterile world has no native spawn candidates")
	check(FrontierEcology.status(empty,form,Vector3.ZERO,"surface")=="absent","terraforming cannot invent native ancestry")
	var hostile: Dictionary=record.duplicate(true);hostile.profile.temperature=-90
	check(FrontierEcology.status(hostile,form,observed.point,"surface")=="dormant","temperature outside tolerated range suppresses active life")
	var water_form:=FrontierEcologyCatalog.form("bio_swimmer_01")
	check(not FrontierEcology.unsuitable(water_form,record.profile,"surface").is_empty(),"marine creature cannot spawn on dry ground")
	var prior:=ecology.duplicate(true)
	FrontierEcology.collect(ecology,source.id,observed)
	check(ecology==prior,"collection requires scan and creates no unobserved specimen")
	FrontierEcology.scan(ecology,source.id,observed)
	check(ecology.observations.size()==1 and ecology.specimens.is_empty(),"scan grants knowledge without creating cargo")
	prior=ecology.duplicate(true);FrontierEcology.scan(ecology,source.id,observed)
	check(ecology==prior,"repeat scan cannot farm permanent research")
	FrontierEcology.collect(ecology,source.id,observed)
	check(ecology.specimens.size()==1 and record.collected.size()==1,"physical sample has one source and one unique cargo identity")
	var sample_id: String=ecology.specimens.keys()[0]
	prior=ecology.duplicate(true);FrontierEcology.collect(ecology,source.id,observed)
	check(ecology==prior,"repeat collection cannot duplicate cargo")
	var found_collected:=false
	for row in FrontierEcologyPlacement.candidates(source,record,Vector3.ZERO):
		if row.id==observed.id:found_collected=true
	check(not found_collected,"collected encounter stays removed when streamed again")
	var supplies: Dictionary={"depot_rock":0}
	FrontierEcology.analyze(ecology,form.id,supplies)
	check(ecology.research.is_empty(),"analysis consumes supplied experimental material")
	supplies.depot_rock=30
	FrontierEcology.analyze(ecology,form.id,supplies)
	check(ecology.research.has("basalt") and supplies.depot_rock==27,"analysis unlocks matching substrate restoration")
	FrontierEcology.analyze(ecology,form.id,supplies)
	check(supplies.depot_rock==27,"repeat research does not consume material")
	FrontierEcology.introduce(ecology,destination.id,sample_id,Vector3.ZERO,"surface")
	check(ecology.specimens[sample_id].state=="cargo","unmanaged release is rejected without losing cargo")
	FrontierEcology.restore_plot(ecology,destination.id,"basalt",Vector3.ZERO,"surface",supplies)
	check(not target.plot.is_empty() and supplies.depot_rock==21,"managed plot requires research and construction material")
	FrontierEcology.introduce(ecology,destination.id,sample_id,Vector3.ZERO,"surface")
	check(ecology.specimens[sample_id].state=="introduced" and target.introductions.size()==1,"source A cargo moves to destination B exactly once")
	FrontierEcology.introduce(ecology,destination.id,sample_id,Vector3.ZERO,"surface")
	check(target.introductions.size()==1,"replayed introduction cannot duplicate a colony")
	FrontierEcology.advance(ecology,destination.id,1)
	check(target.plot.biomass>0,"introduced organism contributes to measured experimental biomass")
	check(FrontierUniverse.validate_world(world).is_empty(),"complete scan-research-cargo-transplant chain validates")
	var succession_world: Dictionary={"planets":{}}
	var dormant_body: Dictionary={}
	for ordinal in 200:
		var candidate:=FrontierUniverse.body(world.manifest,ordinal)
		if candidate.kind=="basalt" and FrontierEcology.profile(candidate).origin=="dormant":dormant_body=candidate;break
	var dormant:=FrontierEcology.ensure_planet(succession_world,dormant_body)
	dormant.plot=target.plot.duplicate(true);dormant.plot.age_seconds=0;dormant.plot.biomass=0
	var microbe: Dictionary={}
	var animal: Dictionary={}
	for lineage in dormant.lineages:
		var definition:=FrontierEcologyCatalog.form(lineage.form_id)
		if definition.environment!="basalt":continue
		if definition.category=="microbe":microbe=definition
		if definition.category=="animal":animal=definition
	check(FrontierEcology.status(dormant,microbe,Vector3.ZERO,"surface")=="dormant","restoration does not instantly conjure active colonies")
	for i in 4:FrontierEcology.advance(succession_world,dormant_body.id,1)
	check(FrontierEcology.status(dormant,microbe,Vector3.ZERO,"surface")=="active" and FrontierEcology.status(dormant,animal,Vector3.ZERO,"surface")=="dormant","pioneer microbes establish before dormant animal lineages")
	for i in 30:FrontierEcology.advance(succession_world,dormant_body.id,1)
	check(FrontierEcology.status(dormant,animal,Vector3.ZERO,"surface")=="active","existing dormant animal lineage awakens after habitat stabilization")
	dormant.plot.support_remaining=0
	var before_biomass: float=dormant.plot.biomass
	FrontierEcology.advance(succession_world,dormant_body.id,9999)
	check(dormant.plot.biomass==before_biomass and FrontierEcology.status(dormant,animal,Vector3.ZERO,"surface")=="dormant","depleted external life support stops production and restored habitat")
	var refills: Dictionary={"depot_rock":0}
	FrontierEcology.resupply_plot(succession_world,dormant_body.id,refills)
	check(dormant.plot.support_remaining==0,"empty stock cannot restore external support")
	refills.depot_rock=3
	FrontierEcology.resupply_plot(succession_world,dormant_body.id,refills)
	check(dormant.plot.support_remaining==3600 and refills.depot_rock==0,"replacement filter and nutrient pack costs real stock")
	check(FrontierEcology.status(dormant,animal,Vector3.ZERO,"surface")=="active","servicing resumes surviving lineage without changing identity")
	check(empty.lineages.is_empty(),"sterile world has no fictional native ancestry to awaken")
	var path: String="user://test_ecology_domain.json"
	var store:=FrontierWorldStore.new(path)
	check(store.write(world),"persist whole ecological transfer: "+store.last_error)
	var restored:=store.read_state()
	check(not restored.is_empty() and restored.ecology.specimens[sample_id].destination==destination.id,"reopened world preserves cargo destination and origin")
	for mutation in ["look","hash","profile","duplicate","origin","research","introduced"]:
		var bad:=world.duplicate(true)
		match mutation:
			"look":bad.ecology.specimens[sample_id].look_id="missing"
			"hash":bad.ecology.catalog_hash="changed"
			"profile":bad.ecology.planets[source.id].profile.temperature=999
			"duplicate":bad.ecology.specimens[sample_id].state="cargo"
			"origin":bad.ecology.planets[source.id].collected.clear()
			"research":bad.ecology.observations.clear()
			"introduced":bad.ecology.planets[destination.id].introductions[sample_id].position=[NAN,0,0]
		check(not FrontierUniverse.validate_world(bad).is_empty(),"reject malformed ecological state: "+mutation)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	print("ECOLOGY_CHECKS ",checks," FAILURES ",failures," source=",source.ordinal," destination=",destination.ordinal," actors=",placed.size())
	quit(1 if failures else 0)
