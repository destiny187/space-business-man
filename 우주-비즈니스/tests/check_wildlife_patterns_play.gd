extends "res://tests/check_wildlife_combat.gd"
var captured: Dictionary={}
func run() -> void:
	fixture_construction="bovid" if "--charge" in OS.get_cmdline_user_args() else "felid"
	await super.run()
func aim() -> void:
	super.aim()
	var live:=FrontierWildlifeCombat.state(core.world.crew,body.id,chosen)
	if live.is_empty() or live.phase!="attack":return
	var info:=FrontierWildlifeCombat.profile(chosen)
	var stage:="windup" if float(live.time)<float(info.windup) else ("motion" if float(live.time)<float(info.windup)+float(info.active) else "recovery")
	if captured.has(stage):return
	if stage=="windup" and float(live.time)<float(info.windup)*.7:return
	if stage=="motion" and float(live.time)<float(info.windup)+float(info.active)*.35:return
	captured[stage]=true
	print("NATIVE_PATTERN_FRAME ",fixture_construction," ",stage," ",JSON.stringify(live))
	if stage=="motion":
		check(animal.position.distance_to(FrontierWildlifeCombat.body_position(live))<.4,"committed motion matches elevated visible collider")
		if fixture_construction=="felid":check(float(live.get("air_height",0))>.6,"natural felid visibly airborne")
	capture("patterns-"+fixture_construction+"-"+stage)

func capture(name_value: String) -> void:
	# A 300 ms UI settling delay hides the short flight and charge contact frames.
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name_value+".png")
