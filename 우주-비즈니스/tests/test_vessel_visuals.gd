extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var parent:=Node3D.new();root.add_child(parent)
	var view:=FrontierVesselVisuals.new();parent.add_child(view)
	var vessel:=FrontierVesselRefit.create(1)
	vessel.loadout.propulsion=FrontierVesselRefit.add_module(vessel,"drive","standard")
	vessel.loadout.utility=FrontierVesselRefit.add_module(vessel,"lab","standard")
	view.update_loadout(vessel)
	for i in 300:
		await process_frame
		if view.installed.size()==2:break
	assert(view.installed.size()==2)
	var drive: Node3D=view.installed.propulsion;var lab: Node3D=view.installed.utility
	FrontierVesselRefit.add_module(vessel,"cargo","standard");view.update_loadout(vessel)
	assert(view.installed.propulsion==drive and view.installed.utility==lab and view.requested.is_empty())
	vessel.modules[vessel.loadout.propulsion].grade="improved";view.update_loadout(vessel)
	assert(view.installed.propulsion==drive and view.installed.utility==lab)
	vessel.loadout.utility="";view.update_loadout(vessel)
	assert(view.installed.propulsion==drive and not view.installed.has("utility"))
	print("VESSEL_VISUAL_CHECKS 4 FAILURES 0")
	parent.queue_free();await process_frame;quit()
