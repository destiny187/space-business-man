extends SceneTree
func _initialize() -> void:
 var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),FrontierPlayerProfile.new_character("연결 저장 검증",0),func(_w):return true)
 var world: Dictionary=core.world;var trace:=FrontierCorporateTraces.definition(world.manifest,"trace:corp_2805_0")
 world.crew.corporate_traces={trace.id:2};FrontierCooperTechClues.capture(world,trace)
 var id: String=world.coopertech_clues[trace.id].incident
 var valid:=FrontierUniverse.validate_world(world).is_empty()
 var malformed:=world.duplicate(true);malformed.incidents.records[id]=7
 var rejected_row:=not FrontierUniverse.validate_world(malformed).is_empty()
 var missing:=world.duplicate(true);missing.incidents.records.erase(id)
 var rejected_link:=not FrontierUniverse.validate_world(missing).is_empty()
 print("CORPORATE_LINK_VALIDATION valid=",valid," malformed_record_rejected=",rejected_row," missing_target_rejected=",rejected_link)
 quit(0 if valid and rejected_row and rejected_link else 1)
