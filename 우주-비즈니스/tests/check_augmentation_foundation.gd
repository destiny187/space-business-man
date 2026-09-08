extends "res://tests/test_crew_surface.gd"
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("증강 기반 확인",0)
	var source:=FrontierUniverse.new_world(71491)
	source.crew=FrontierCrewWorld.create(owner)
	var old: Dictionary=source.crew.members[owner.character_id]
	old.erase("augmentation");old.loadout.research={"logistics":3};old.vitals.health=80.0
	var old_slots:=FrontierItemInventory.capacity(old)
	var core:=FrontierCrewAuthority.new()
	check(core.start(source,owner,persist),"legacy world opens and migrates")
	var member: Dictionary=core.world.crew.members[owner.character_id]
	check(member.augmentation.levels.mobility==3 and is_equal_approx(FrontierCrewAugmentation.multiplier(member,"mobility"),1.3),"paid speed retained once")
	check(FrontierItemInventory.capacity(member)==old_slots and member.vitals.health==80.0,"bag and current health retained")
	check(not source.crew.members[owner.character_id].has("augmentation"),"source save untouched")
	member.loadout.research.logistics=4
	FrontierCrewAugmentation.ensure(member)
	check(member.augmentation.levels.mobility==3 and FrontierItemInventory.capacity(member)==old_slots+1,"future bag growth does not double speed")
	member.augmentation.levels.combat=3;member.augmentation.levels.vitality=2
	member.loadout.items["fixture:pulse"]="pulse_1";member.loadout.slots[1]="fixture:pulse";member.loadout.selected=1
	check(FrontierEquipment.active(member).damage==26,"personal damage affects actual pulse definition")
	member.loadout.items["fixture:pulse"]="pulse_2"
	check(FrontierEquipment.active(member).damage==52 and FrontierEquipment.config().items.pulse_2.damage==40,"weapon replacement keeps bonus without mutating catalog")
	member.loadout.selected=0
	check(FrontierEquipment.active(member).damage==FrontierEquipment.config().items[member.loadout.items[member.loadout.slots[0]]].damage,"combat does not modify mining tool")
	check(is_equal_approx(FrontierCrewAugmentation.maximum_health(member),140.0),"maximum health grows")
	member.vitals.health=139.0;member.vitals.hurt=0.0;member.area="cabin"
	FrontierCrewVitals.step(member,1,false,false)
	check(is_equal_approx(member.vitals.health,140.0) and FrontierCrewVitals.validate(member.vitals,member),"healing and save cap use increased maximum")
	member.vitals.health=141.0
	check(not FrontierCrewVitals.validate(member.vitals,member),"health above personal cap rejected")
	member.vitals.health=120.0
	for invalid in [-1,1.5,6,"2",null]:
		var broken: Dictionary=member.augmentation.duplicate(true);broken.levels.combat=invalid
		check(not FrontierCrewAugmentation.validate(broken),"invalid augmentation rejected: "+str(invalid))
	var broken: Dictionary=member.augmentation.duplicate(true);broken.levels.erase("combat")
	check(not FrontierCrewAugmentation.validate(broken),"missing field rejected")
	var guest:=FrontierPlayerProfile.new_character("증강 동료",1)
	guest.augmentation=FrontierCrewAugmentation.create(5)
	var admitted:=core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(admitted.ok and core.acknowledge(2,core.session_id).ok,"guest joins")
	check(core.world.crew.members[guest.character_id].augmentation.levels.mobility==0,"profile cannot grant world augmentation")
	core.world.crew.members[guest.character_id].augmentation.levels.vitality=1
	check(core.disconnect_member(2),"disconnect preserves world record")
	admitted=core.admit(2,guest,admitted.token,int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
	check(admitted.ok and core.acknowledge(2,core.session_id).ok and core.world.crew.members[guest.character_id].augmentation.levels.vitality==1,"reconnect keeps personal augmentation")
	check(core.world.crew.members[owner.character_id].augmentation.levels.combat==3,"guest changes do not modify host")
	var serialized: Dictionary=JSON.parse_string(JSON.stringify(core.world))
	var restored:=FrontierCrewAuthority.new()
	check(restored.start(serialized,owner,persist),"JSON save reloads personal stats")
	check(restored.world.crew.members[owner.character_id].augmentation.levels.mobility==3,"reloading does not remigrate later bag levels")
	check(not owner.has("augmentation"),"original profile stays unchanged")
	check(request(restored,1,"start_game").ok,"start isolated surface fixture")
	# Prepare orbit directly: this check targets augmentation, not route/range progression.
	var destination:=FrontierCrewNavigation.first_destination(restored.world.manifest)
	var body:=FrontierUniverse.body(restored.world.manifest,destination)
	restored.world.crew.navigation.system=FrontierUniverse.system_index(restored.world.manifest,destination)
	restored.world.crew.navigation.target=destination
	var orbit:=FrontierCrewNavigation.center(destination,restored.world.manifest)+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1)
	restored.world.crew.navigation.position=FrontierExpeditionBusiness.array(orbit)
	ready_all(restored)
	var landing:=request(restored,1,"land")
	check(landing.ok,"land actual fixture for runtime inspection: "+str(landing.get("error","")))
	DirAccess.make_dir_recursive_absolute("/tmp/augmentation-a01")
	check(FrontierWorldStore.new("/tmp/augmentation-a01/world.json").write(restored.world),"isolated fixture saved")
	print("AUGMENTATION_A01 ",checks," FAILURES ",failures)
	quit(1 if failures else 0)
