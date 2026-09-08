extends SceneTree
func _initialize() -> void:
	var world:=FrontierUniverse.new_world(71491)
	assert(FrontierUniverse.validate_world(world).is_empty())
	var body:=FrontierUniverse.body(world.manifest,FrontierCrewNavigation.first_destination(world.manifest))
	assert(FrontierGroundProgression.intro_candidate(body))
	var total: Dictionary={}
	for row in FrontierExpeditionBusiness.starter_veins(body):
		total[row.resource]=int(total.get(row.resource,0))+int(row.capacity)
		assert(Vector2(row.position[0],row.position[2]).length()>=20 and Vector2(row.position[0],row.position[2]).length()<=80)
	assert(total=={"iron":610,"copper":205,"stone":195,"ice":150})
	var old: Dictionary=world.duplicate(true);old.manifest.settings.erase("ground_rules");old.manifest_hash=FrontierUniverse.fingerprint(old.manifest)
	var old_body:=FrontierUniverse.body(old.manifest,FrontierCrewNavigation.first_destination(old.manifest))
	assert(FrontierExpeditionBusiness.starter_veins(old_body)[0].id=="landing:iron")
	assert(FrontierUniverse.validate_world(old).is_empty())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--legacy="):
			var saved:=FrontierWorldStore.new(arg.trim_prefix("--legacy=")).read_state()
			assert(not saved.is_empty())
			print("LEGACY_SAVED_SITE_VALID ",saved.location)
	print("GROUND_RULES_OK ",total);quit()
