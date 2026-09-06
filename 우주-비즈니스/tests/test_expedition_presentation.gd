extends "res://tests/test_solo_entry.gd"

func capture(name_value: String) -> void:
	if name_value=="landed":
		check(app.feedback.handheld.is_visible_in_tree(),"current solo entry equips original Blender tool")
		check(app.feedback.parts.size()>0,"tool animated joints preserved")
		check(app.feedback.audio.ambient.playing,"landed world plays ElevenLabs ambience")
		check(app.feedback.audio.ambient_key=="amb_barren_wind","barren sound selected from actual environment")
		app.pitch=-1.2;await create_timer(.3).timeout
		var before: int=app.feedback.effects.emitted.pulse
		app.surface_action("surface_dig")
		check(app.feedback.effects.emitted.pulse==before+1,"accepted excavation emits pulse and recoil")
		check(app.feedback.audio.last_played.has("sfx_combat_pulse"),"accepted excavation plays original pulse sound")
		await super.capture("tool-action")
		app.pitch=1.1;await create_timer(.5).timeout
		before=app.feedback.effects.emitted.pulse
		app.surface_action("surface_dig")
		check(app.feedback.effects.emitted.pulse==before,"rejected excavation never shows success")
		check(app.feedback.audio.last_played.has("sfx_build_invalid"),"failed action plays failure sound")
		app.pitch=0
		app.toggle_business();await create_timer(.3).timeout
		check(not app.feedback.handheld.visible,"menu suppresses handheld")
		check(app.feedback.audio.ambient.stream_paused,"menu suppresses ambient playback")
		var old: int=app.session.surface.edits.size()
		app.surface_action("surface_dig");app.interact_business()
		check(app.session.surface.edits.size()==old,"menu blocks field actions")
		app.toggle_business();await create_timer(.3).timeout
		check(app.feedback.handheld.visible and not app.feedback.audio.ambient.stream_paused,"field presentation resumes after menu")
		verify_audio_adapter()
	if name_value=="business-960":
		var panel: FrontierBusinessPanel=app.business_panel
		check(panel.building_cards.size()==FrontierExpeditionBusiness.config().buildings.size(),"every buildable facility has visual card")
		for kind in panel.building_cards:
			var card: Button=panel.building_cards[kind]
			check(card.get_child(0).get_child(0).texture!=null,"actual game preview: "+kind)
			card.pressed.emit()
			check(panel.selected(panel.building)==kind and card.button_pressed,"card selects real construction: "+kind)
		check(panel.get_global_rect().end.x<=960,"visual construction panel fits small viewport")
		await super.capture(name_value)
		panel.hide();app.begin_placement("solar");app.pitch=-.6;await create_timer(.5).timeout
		check(app.placement_ghost!=null,"selected facility has actual world placement model")
		await super.capture("placement-960")
		app.cancel_placement();app.pitch=0;panel.show()
		return
	await super.capture(name_value)

func verify_audio_adapter() -> void:
	# Presentation-only fixture: no authoritative state, materials or saves are modified.
	var original: Dictionary=app.session.surface
	var packet: Dictionary=original.duplicate(true)
	var position: Vector3=app.actors[app.session.latest.self_id].position
	var robots: Dictionary={}
	var statuses: Array[String]=["채광 중","충전 중","광맥으로 이동","창고로 운반","충전기 복귀"]
	for i in statuses.size():robots[str(i)]={"id":str(i),"position":[position.x+1,position.y+2,position.z],"status":statuses[i]}
	packet.business={"sites":{app.surface_world.body.id:{"environment":{"ecology":50},"robots":robots,"buildings":{"fan":{"id":"fan","position":[position.x,position.y,position.z+2],"type":"atmosphere","active":true}}}}}
	app.session.surface=packet;app.feedback._update_audio(true)
	check(app.feedback.audio.ambient_key=="amb_restored_nature","restoration selects existing nature recording")
	for i in statuses.size():
		var emitter: AudioStreamPlayer3D=app.feedback.audio.emitters.get(str(i))
		check(emitter!=null and emitter.playing,"actual expedition status has audio: "+statuses[i])
		if emitter!=null:check(is_equal_approx(emitter.position.y,position.y+2.8),"3D source height preserved: "+statuses[i])
	check(app.feedback.audio.emitters.has("fan"),"active terraforming facility has spatial fan loop")
	app.session.surface=original;app.feedback._update_audio(true)
	check(app.feedback.audio.emitters.is_empty(),"removed machines leave no orphan audio")
