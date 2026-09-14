extends "res://tests/test_crew_surface.gd"
const Draft=preload("res://scripts/persistence/world_draft.gd")
func run() -> void:
 var fixture:=FrontierWorldStore.new("/tmp/facility-design-play/world.json").read_state()
 if fixture.is_empty():quit(2);return
 var owner: Dictionary=fixture.crew.members[fixture.crew.owner_id].profile
 var core:=FrontierCrewAuthority.new()
 check(core.start(fixture,owner,persist),"saved expedition starts")
 core.phase="playing";sequences[1]=core.world.crew.members[owner.character_id].last_sequence
 var guest:=FrontierPlayerProfile.new_character("공동 건설 동료",1)
 var join:=core.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
 check(join.ok and core.acknowledge(2,core.session_id).ok,"guest admits without construction permission prompt")
 var member: Dictionary=core.world.crew.members[guest.character_id]
 member.area="surface";member.aboard=false
 core.world.business.bags[guest.character_id]=FrontierExpeditionBusiness.inventory()
 var field:=FrontierCrewSurface.field(core.world)
 var point:=Vector3.INF
 var cost: Dictionary=FrontierFacilityResearch.construction("solar").cost
 for resource in cost:core.world.business.bags[guest.character_id][resource]=cost[resource]
 for x in range(-40,41,4):
  if point.is_finite():break
  for z in range(-40,41,4):
   var p:=FrontierExpeditionBusiness.ground(field,x,z,2.2)
   if not p.is_finite():continue
   member.position=FrontierExpeditionBusiness.array(p+Vector3(0,.1,5))
   if FrontierExpeditionBusiness.build_reason(core.world,guest.character_id,"solar",p,core.peers).is_empty():point=p;break
 check(point.is_finite(),"guest has valid placement")
 if not point.is_finite():quit(1);return
 var stock: Dictionary=core.world.business.bags[owner.character_id].duplicate()
 var request_value:=envelope(core,2,"business_build",{"building":"solar","position":FrontierExpeditionBusiness.array(point)})
 disk_ok=false;var result:=core.request(2,request_value)
 check(not result.ok and not core.world.crew.get("play_guide",{}).get("built",false),"failed save cannot advance shared build")
 disk_ok=true;result=core.request(2,request_value)
 print("GUEST_BUILD ",result)
 check(result.ok and core.world.crew.play_guide.built,"guest builds and advances shared milestone in same commit")
 check(core.world.business.bags[owner.character_id]==stock,"guest construction preserves host backpack")
 var revision: int=core.world.crew.revision
 check(core.request(2,request_value)==result and core.world.crew.revision==revision,"duplicate build does not charge or advance again")
 check(core.snapshot(1).crew.play_guide==core.snapshot(2).crew.play_guide,"host and guest receive identical milestone")
 var scoped:=Draft.request(core.world,guest.character_id,"guide_progress")
 FrontierSharedPlayGuide.merge(scoped.crew,["terraform_view"])
 check(not core.world.crew.play_guide.get("terraform_view",false),"guide draft does not mutate live milestone")
 check(is_same(scoped.business,core.world.business) and is_same(scoped.terrain_edits,core.world.terrain_edits),"guide report shares unchanged industry and terrain")
 member=core.world.crew.members[guest.character_id];member.aboard=true;member.area="cabin"
 var guide:=envelope(core,2,"guide_progress",{"steps":["inventory","field_scan","materials_review","terraform_view"]});guide.revision=-1
 check(core.request(2,guide).ok,"onboard guest can merge guide observations across stale revision")
 check(core.world.crew.play_guide.built and core.world.crew.play_guide.terraform_view,"guide union retains other participant progress")
 check(not request(core,2,"guide_progress",{"steps":["unlocked_all"]}).ok,"unknown milestones rejected")
 var late:=FrontierPlayerProfile.new_character("늦게 합류한 동료",2)
 var later:=core.admit(3,late,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash())
 check(later.ok and core.acknowledge(3,core.session_id).ok and core.snapshot(3).crew.play_guide.built,"late join receives completed build")
 var stored:=FrontierWorldStore.new("/tmp/shared-guide-rules.json")
 check(stored.write(core.world) and stored.read_state().crew.play_guide==core.world.crew.play_guide,"shared milestones survive real save read")
 var empty:=FrontierCrewWorld.create(owner)
 check(empty.get("play_guide",{}).is_empty(),"new expedition starts without shared milestones")
 var session:=FrontierCrewSession.new()
 check(not session._surface_command("guide_progress"),"guide report requests no surface rebuild publication");session.free()
 print("SHARED_GUIDE_RULES ",checks," FAILURES ",failures);quit(1 if failures else 0)
