extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:failures += 1;printerr("FAIL: "+message)
func run() -> void:
	var start := Time.get_ticks_usec()
	var world: Dictionary = FrontierUniverse.new_world(71491)
	check(FrontierUniverse.validate_world(world).is_empty(),"sparse world validates")
	check(world.manifest.settings.planet_count==1000000,"one million bounded addresses")
	check(not world.manifest.has("bodies") and not world.manifest.has("systems"),"no eager galaxy allocation")
	check(JSON.stringify(world).length()<65536,"unvisited galaxy save below 64 KiB")
	check(FrontierUniverse.fingerprint(world)==FrontierUniverse.fingerprint(FrontierUniverse.new_world(71491)),"same seed reproduces manifest")
	var ids := {}
	for ordinal in [0,1,3,4,199999,200000,799999,999998,999999]:
		var body: Dictionary = FrontierUniverse.body(world.manifest,ordinal)
		check(body.ordinal==ordinal and not ids.has(body.id),"boundary address resolves uniquely")
		ids[body.id]=true
		check(FrontierUniverse.body_from_id(world.manifest,body.id)==body,"ID roundtrip")
		check(FrontierUniverse.body(world.manifest,ordinal)==body,"lazy generation is deterministic")
	for ordinal in [-1,1000000]:check(FrontierUniverse.body(world.manifest,ordinal).is_empty(),"out of range rejected")
	check(FrontierUniverse.ordinal_of(world.manifest,"galaxy:wrong:planet:0")==-1,"cross-world ID rejected")
	check(FrontierUniverse.ordinal_of(world.manifest,world.manifest.id+":planet:01")==-1,"noncanonical duplicate ID rejected")
	var sums := [0,0,0,0,0]
	for seed_value in 10:
		var m: Dictionary = FrontierUniverse.generate(seed_value)
		var valid := true
		for band in 5:
			for i in 100:
				var ordinal: int = band*200000 + FrontierUniverse.derive(seed_value,"sample:%d:%d" % [band,i])%200000
				var body: Dictionary = FrontierUniverse.body(m,ordinal)
				sums[band]+=int(body.planet_tier)
				valid = valid and body.origin=="fictional" and body.streams.terrain!=body.streams.ecology
				valid = valid and FrontierUniverse.system(m,ordinal/4).band==band
		check(valid,"provenance, streams and band across sampled addresses")
	var means: Array=[]
	for band in 5:
		means.append(float(sums[band])/1000.0)
		if band>0:check(means[band]>means[band-1],"distribution rises toward centre")
	print("TIER_MEANS ",means)
	for record in world.manifest.catalog.records:
		check(record.surface_map==null and record.life_observed==null,"unknown surface and life remain null")
		check(record.references.pl_refname!=null,"published reference retained")
	var body0: Dictionary=FrontierUniverse.body(world.manifest,0)
	world.visited[body0.id]=true
	var store:=FrontierWorldStore.new("user://test_sparse_world.json")
	check(store.write(world),"atomic sparse write")
	world.location=FrontierUniverse.body_id(world.manifest,999999)
	check(store.write(world),"last address write")
	check(store.read_state().location==world.location,"last address restore")
	var restored: Dictionary=store.read_state()
	check(FrontierUniverse.body(restored.manifest,0)==body0,"saved generator and catalogue pin bodies")
	var bad: Dictionary=world.duplicate(true)
	bad.manifest.seed=42
	check(not store.write(bad),"checksum blocks modified original")
	var file:=FileAccess.open(store.path,FileAccess.WRITE);file.store_string("{broken");file.close()
	check(not store.read_state().is_empty() and not store.last_error.is_empty(),"backup recovery")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(store.path+suffix):DirAccess.remove_absolute(store.path+suffix)
	for malformed in [null,[],{}, {"version":2}]:check(not FrontierUniverse.validate_world(malformed).is_empty(),"malformed save rejected")
	print("SPARSE_GALAXY bytes=",JSON.stringify(world).length()," sample_build_ms=",(Time.get_ticks_usec()-start)/1000.0)
	print("UNIVERSE_CHECKS ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
