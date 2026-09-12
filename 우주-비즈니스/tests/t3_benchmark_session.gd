extends FrontierCrewSession
## Local benchmark transport: both actors use host collision/game rules, no network latency.
## Fixed-step game clock also drives the host's mining cooldown.
var elapsed:=0.0
func _process(delta: float) -> void:
 if not hosting or authority==null or authority.stopped:return
 surface_timer-=delta;snapshot_timer-=delta
 if surface_timer<=0:surface_timer=.5;_publish_surface()
 if snapshot_timer<=0:snapshot_timer=.1;_publish()
func _physics_process(delta: float) -> void:
 if hosting and active and authority.phase=="playing":elapsed+=minf(delta,.1);authority.advance_time(elapsed)
 super._physics_process(delta)
func _publish() -> void:
 if not hosting or authority==null or authority.stopped:return
 snapshot_serial+=1;latest=authority.snapshot(1);snapshot_received.emit(latest)
func _publish_surface() -> void:
 if not hosting or authority==null or authority.stopped or authority.phase!="playing":return
 var local:=FrontierShuttles.context(authority.world,authority.peers[1])
 var value:=FrontierCrewSurfaceReplica.packet(local,authority.peers[1])
 if value.is_empty():surface={};return
 if authority.water_solvers.has(value.body_id):value.water_columns=authority.water_solvers[value.body_id].columns_packet(FrontierCrewWorld.vector(local.crew.members[authority.peers[1]].position))
 surface=value;surface_received.emit(value)
