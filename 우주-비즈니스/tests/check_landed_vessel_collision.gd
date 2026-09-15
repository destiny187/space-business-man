extends "res://tests/test_solo_entry.gd"
func run() -> void:
	var stage:=Node3D.new();root.add_child(stage)
	var terrain:=FrontierTerrainStreamer.new();terrain.configure(71491,[],null);stage.add_child(terrain)
	var world:=FrontierUniverse.new_world(71491)
	var owner:=FrontierPlayerProfile.new_character("충돌 검수",0)
	var authority:=FrontierCrewAuthority.new();authority.start(world,owner,func(_world):return true)
	world=authority.world
	var remote:=preload("res://scripts/world/remote_landed_vessels.gd").new();stage.add_child(remote);remote.configure(terrain)
	remote.sync(world,owner.character_id)
	await process_frame
	check(remote.ready() and remote.ship.has_node("GroundHullCollision"),"remote host world installs common hull collision")
	var original: Node=remote.ship.get_node("GroundHullCollision")
	remote.sync(world,owner.character_id)
	check(remote.ship.get_node("GroundHullCollision")==original,"unchanged snapshot keeps same collision body")
	# Model replacement follows the same async refit path used on the surface.
	world.vessel={"hull":"swift"}
	remote.sync(world,owner.character_id)
	check(not remote.ready(),"remote walking waits for replacement hull collision")
	for frame in 500:
		await process_frame;remote.sync(world,owner.character_id)
		if remote.ready():break
	check(remote.ready() and remote.ship.get_node("GroundHullCollision")!=original,"hull replacement installs new collision once")
	stage.queue_free();await process_frame
	print("LANDED_VESSEL_COLLISION ",checks," FAILURES ",failures);quit(1 if failures else 0)
