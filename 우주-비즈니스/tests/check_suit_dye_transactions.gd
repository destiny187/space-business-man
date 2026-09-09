extends "res://tests/test_crew_surface.gd"
func run() -> void:
	var owner:=FrontierPlayerProfile.new_character("염색 호스트",0)
	var core:=FrontierCrewAuthority.new();check(core.start(FrontierUniverse.new_world(71491),owner,persist),"start")
	check(request(core,1,"start_game").ok,"play")
	core.world.business=FrontierExpeditionBusiness.create()
	core.world.business.bags[owner.character_id]=FrontierExpeditionBusiness.inventory();core.world.business.bags[owner.character_id]["sapphire"]=2
	var args: Dictionary={"part":"helmet","colors":{"primary":"ff9933"},"expected":{}}
	var retry:=envelope(core,1,"suit_dye",args)
	disk_ok=false;var before:=FrontierUniverse.fingerprint(core.world)
	check(not core.request(1,retry).ok and before==FrontierUniverse.fingerprint(core.world),"failed disk write rolls back color and gem")
	disk_ok=true;var result:=core.request(1,retry);check(result.ok,"retry commits")
	before=FrontierUniverse.fingerprint(core.world);check(core.request(1,retry)==result and before==FrontierUniverse.fingerprint(core.world),"same request charges once")
	for invalid in [{"part":"unknown","colors":{},"expected":{}},{"part":"chest","colors":{"primary":"nan"},"expected":{}},{"part":"chest","colors":{"primary":"ff0000"},"expected":{},"price":0},args]:
		before=FrontierUniverse.fingerprint(core.world);check(not request(core,1,"suit_dye",invalid).ok and before==FrontierUniverse.fingerprint(core.world),"invalid or stale request unchanged")
	var guest:=FrontierPlayerProfile.new_character("염색 동료",1)
	check(core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok and core.acknowledge(2,core.session_id).ok,"guest joins")
	core.world.business.bags[guest.character_id]=FrontierExpeditionBusiness.inventory();core.world.business.bags[guest.character_id]["sapphire"]=1
	check(request(core,2,"suit_dye",{"part":"legs","colors":{"accent":"33aacc"},"expected":{}}).ok,"guest dyes own suit")
	check(core.world.business.bags[owner.character_id]["sapphire"]==1 and not core.world.crew.members[owner.character_id].suit_dyes.has("legs"),"host gems and colors isolated")
	check(core.snapshot(1).crew.members[guest.character_id].suit_dyes.legs.accent=="33aacc" and core.snapshot(2).crew.members[owner.character_id].suit_dyes.helmet.primary=="ff9933","both snapshots carry confirmed peer colors")
	print("SUIT_DYE_TRANSACTIONS ",checks," FAILURES ",failures);quit(1 if failures else 0)
