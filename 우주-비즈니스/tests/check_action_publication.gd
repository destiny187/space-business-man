extends SceneTree
class PublicationProbe extends FrontierCrewSession:
 var snapshots:=0
 var surfaces:=0
 func _publish() -> void:snapshots+=1
 func _publish_surface() -> void:surfaces+=1
var failures:=0
func _initialize() -> void:
 var session:=PublicationProbe.new()
 session.authority=FrontierCrewAuthority.new()
 session.authority.world={"crew":{"revision":7}}
 session.authority.phase="playing"
 var before:=session._request_publication_state()
 var envelope: Dictionary={"kind":"business_build","revision":7}
 session._publish_request_result(envelope,{"ok":false},before)
 check(session.snapshots==0 and session.surfaces==0,"unchanged rejection builds no snapshots")
 session._publish_request_result(envelope,{"ok":true},before)
 check(session.snapshots==0 and session.surfaces==0,"receipt replay builds no snapshots")
 envelope.revision=6
 session._publish_request_result(envelope,{"ok":false},before)
 check(session.snapshots==1 and session.surfaces==0,"stale failure still receives current crew state")
 envelope.revision=7;session.authority.world.crew.revision=8
 session._publish_request_result(envelope,{"ok":true},before)
 check(session.snapshots==2 and session.surfaces==1,"committed change publishes crew and surface")
 before=session._request_publication_state();session.authority.lobby_ready["guest"]=true
 session._publish_request_result({"kind":"lobby_ready"},{"ok":true},before)
 check(session.snapshots==3,"readiness changes publish without a world revision change")
 before=session._request_publication_state();session.authority.phase="lobby"
 session._publish_request_result({"kind":"start_game"},{"ok":true},before)
 check(session.snapshots==4,"phase changes publish without a world revision change")
 session.authority.world.crew.revision=9
 session._publish_request_result({"kind":"business_mine"},{"pending":true},before)
 check(session.snapshots==4,"pending extraction has no premature publication")
 session._publish_request_result({"kind":"surface_fire"},{"ok":true},before)
 check(session.snapshots==4,"firearm commands keep their separate publication cadence")
 session.free();print("ACTION_PUBLICATION failures ",failures);quit(1 if failures else 0)
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
