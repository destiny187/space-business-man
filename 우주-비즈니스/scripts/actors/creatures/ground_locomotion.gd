extends RefCounted
## Visual locomotion only. The actor root and combat clocks remain authoritative.
const Feet=preload("res://scripts/actors/creatures/ground_locomotion_feet.gd")
static var settings: Dictionary={}
static var catalogue: Dictionary={}
var actor: Node3D
var enabled:=false
var driven:=false
var initialized:=false
var kind:="crawl"
var profile: Dictionary={}
var limbs: Array=[]
var chains: Dictionary={}
var contacts: Array[Dictionary]=[]
var visual: Node3D
var point:=Vector3.ZERO
var frame:=Basis.IDENTITY
var velocity:=Vector3.ZERO
var speed:=0.0
var travel_speed:=0.0
var frequency:=0.0
var skin_bindings: Array[Dictionary]=[]
var phase:=0.0
var idle_clock:=0.0
var intensity:=0.0
var running:=0.0
var turn_speed:=0.0
var leg_length:=1.0
var body_length:=1.0
var cycle_length:=1.0
var stance:=.7
var dt:=0.0
var probe: Callable
var footfalls: Array[Vector3]=[]
var sound_left:=0.0
var pose_history: Array[Dictionary]=[]
var previous_state:=""
var transition_left:=0.0
var source_frame:=-1
var ground_revision:=-1
var contact_interval:=0.0
var contact_elapsed:=0.0
var contacts_suspended:=false

static func config() -> Dictionary:
	if settings.is_empty():settings=JSON.parse_string(FileAccess.get_file_as_string("res://data/ground_locomotion.json"))
	return settings

func configure(owner: Node3D,display: Node3D) -> void:
	actor=owner;visual=display
	if catalogue.is_empty():catalogue=JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/ground_locomotion.json")).forms
	enabled=catalogue.has(actor.definition.id)
	if not enabled:return
	var data: Dictionary=catalogue[actor.definition.id]
	kind=data.kind;limbs=data.limbs;profile=config().kinds[kind].duplicate()
	if actor.definition.get("construction",actor.definition.family) in config().heavy_types:
		profile.bob*=.5;profile.lift*=.8;profile.stride*=.85
	for chain in actor.definition.get("gait",{}).get("limbs",{}).values():chains[chain.hip]=chain
	var total:=0.0
	for limb in limbs:
		if chains.has(limb.hip):
			var chain: Dictionary=chains[limb.hip]
			total+=v(chain.upper).length()+v(chain.lower).length()
		else:total+=v(limb.tip).length()
	var bounds: Dictionary=actor.definition.geometry.near
	body_length=maxf(.2,float(bounds.max[2])-float(bounds.min[2]))
	leg_length=maxf(.15,total/maxi(1,limbs.size())) if not limbs.is_empty() else body_length*.35
	cycle_length=maxf(.1,leg_length*float(profile.stride)*.65)
	for lod in actor.models.size():bind_skin(lod)
	for limb in limbs:contacts.append({"ready":false,"swing":false,"cycle":-1000,"position":Vector3.ZERO,"normal":Vector3.UP})

static func v(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

func reset() -> void:
	initialized=false;velocity=Vector3.ZERO;speed=0;intensity=0;footfalls.clear();pose_history.clear()
	for contact in contacts:contact.ready=false;contact.swing=false

func drive(target: Transform3D,delta: float,sampler: Callable,stopped: bool,interval: float=0.0,revision: int=-1) -> void:
	driven=true;probe=sampler;source_frame=Engine.get_process_frames()
	ground_revision=revision;contact_interval=interval
	if contacts_suspended and interval>=0:
		for contact in contacts:contact.ready=false;contact.swing=false
		contact_elapsed=0.0
	contacts_suspended=interval<0
	actor.global_transform=target
	if stopped:
		# The parent can still receive snapshots while a solo menu/focus pause is open.
		if initialized:visual.global_transform=Transform3D(frame,point)
		return
	dt=minf(delta,.15)
	var scale_value: float=actor.base_scale
	if not initialized or point.distance_to(target.origin)>maxf(3.0,body_length*scale_value*float(config().teleport_lengths)):
		point=target.origin;frame=target.basis;initialized=true
		for contact in contacts:contact.ready=false
	var previous:=point;var previous_frame:=frame
	point=point.lerp(target.origin,1-exp(-dt/float(config().position_seconds)))
	var cap: float=float(config().maximum_visual_offset)*minf(2.0,scale_value)
	point=target.origin+(point-target.origin).limit_length(cap)
	var a:=frame.orthonormalized().get_rotation_quaternion();var b:=target.basis.orthonormalized().get_rotation_quaternion()
	var limit: float=config().combat_turn_radians_per_second if actor.combat_override else config().turn_radians_per_second
	frame=Basis(a.slerp(b,minf(1.0,limit*dt/maxf(.0001,a.angle_to(b)))))
	visual.global_transform=Transform3D(frame,point)
	var displacement:=point-previous
	var horizontal:=Vector3(displacement.x,0,displacement.z)
	velocity=horizontal/maxf(.001,dt)
	turn_speed=wrapf(frame.get_euler().y-previous_frame.get_euler().y,-PI,PI)/maxf(.001,dt)
	var travel:=horizontal.length()
	# A turning animal lifts and repositions feet even when its centre stays still.
	travel=maxf(travel,absf(turn_speed)*dt*leg_length*scale_value*.30)
	advance(travel,dt)

func preview(delta: float) -> void:
	if driven or not enabled or actor.paused:return
	dt=minf(delta,.15);point=actor.global_position;frame=actor.global_basis.orthonormalized();initialized=true
	var nominal:=leg_length*float(actor.base_scale)*float(profile.stride)*.75*float(actor.movement_rate)
	var travel: float=nominal*dt if actor.state=="move" else 0.0
	velocity=frame.z*nominal if actor.state=="move" else Vector3.ZERO
	advance(travel,dt)

func advance(travel: float,delta: float) -> void:
	idle_clock+=delta;sound_left=maxf(0,sound_left-delta)
	var moving:=travel/maxf(.001,delta)
	travel_speed=moving
	speed=lerpf(speed,moving,1-exp(-delta/float(config().speed_seconds)))
	var scale_value: float=actor.base_scale
	var length_value:=leg_length*scale_value
	running=smoothstep(float(profile.run_speed)*scale_value*.5,float(profile.run_speed)*scale_value,speed)
	intensity=lerpf(intensity,1.0 if moving>float(config().minimum_speed) else 0.0,1-exp(-delta/(.12 if moving>float(config().minimum_speed) else .07)))
	cycle_length=maxf(.10,length_value*float(profile.stride)*lerpf(.65,1.7,running))
	cycle_length=maxf(cycle_length,moving/float(config().maximum_hz))
	stance=minf(lerpf(float(profile.stance),float(profile.stance)*.52,running),length_value*.65/cycle_length)
	stance=clampf(stance,.18,.88)
	frequency=moving/cycle_length
	var previous_phase:=phase
	phase+=travel/cycle_length
	# Limbless ground animals disturb the soil with their body wave instead of footsteps.
	if driven and not contacts_suspended and limbs.is_empty() and sound_left<=0 and floori(previous_phase)!=floori(phase) and moving>float(config().minimum_speed):
		footfalls.append(Feet.ground(self,point).point);sound_left=float(config().footstep_seconds)
	if previous_state!=actor.state:
		transition_left=float(config().pose_seconds);previous_state=actor.state
	transition_left=maxf(0,transition_left-delta)
	if driven and not contacts_suspended:
		contact_elapsed+=delta
		if contact_elapsed>=contact_interval:
			Feet.update(self,contact_elapsed);contact_elapsed=0.0

func offset(index: int) -> float:
	var rest:=v(limbs[index].rest)
	var left:=rest.x<0
	if kind=="hop":return .0 if limbs.size()==2 or rest.z<0 else .48
	if kind=="biped":return 0.0 if left else .5
	if kind=="quadruped":
		var front:=rest.z>=_middle_z()
		var walk:=0.0 if front and left else (.5 if front else (.75 if left else .25))
		var trot:=0.0 if front==left else .5
		# Interpolate on the circle; crossing a gait threshold never resets the cycle.
		return wrapf(walk+wrapf(trot-walk,-.5,.5)*running,0,1)
	if kind=="many":
		var side_index:=0
		for i in index:
			if (v(limbs[i].rest).x<0)==left:side_index+=1
		return fposmod(side_index*(.17 if limbs.size()>8 else .5)+(0 if left else .5),1)
	# Radial and odd-legged supports travel around the actual contact ring.
	return fposmod(atan2(rest.x,rest.z)/TAU,1)

func _middle_z() -> float:
	var low:=INF;var high:=-INF
	for limb in limbs:low=minf(low,float(limb.rest[2]));high=maxf(high,float(limb.rest[2]))
	return (low+high)*.5

func released(index: int) -> bool:
	if actor.state=="dormant":return true
	if actor.combat_override:
		if actor.combat_phase=="down":return true
		if float(actor.combat_live.get("air_height",0))>.03:return true
		if actor.combat_phase=="attack":
			var mode: String=actor.combat_info.get("behavior","")
			var striking: bool=actor.combat_clock>=actor.windup_seconds and actor.combat_clock<actor.windup_seconds+actor.active_seconds
			if striking and mode=="leap":return true
			if actor.combat_pattern in ["claw","scythe"] and v(limbs[index].rest).z>=_middle_z():return true
			if actor.combat_pattern=="kick" and "Leg_0" in str(limbs[index].hip):return true
	elif actor.state=="attack":return true
	return false

func pose(row: Dictionary,lod: int) -> void:
	if not enabled or not actor.is_inside_tree():return
	if not driven:
		point=actor.global_position;frame=actor.global_basis.orthonormalized()
		if actor.state=="move":phase=float(actor.elapsed)*.75
		if dt==0:intensity=1.0 if actor.state=="move" else 0.0
	var body: Node3D=row.Anim_Body.node
	if actor.state!="dormant" and not (actor.combat_override and float(actor.combat_live.get("air_height",0))>.03):
		var bob: float=float(profile.bob)*leg_length*intensity
		var bounce: float=.5-.5*cos(phase*TAU*2)
		if kind=="hop":bounce=sin(clampf((fposmod(phase,1)-stance)/(1-stance),0,1)*PI)
		body.position.y+=bob*bounce
		body.rotation.z+=sin(phase*TAU)*float(profile.roll)*intensity-clampf(turn_speed*.009,-.06,.06)*intensity
		# Compression leaves reach for knees and keeps planted feet below the body.
		if not limbs.is_empty():body.position.y-=leg_length*.025*intensity
		if kind=="crawl":body.scale.z*=1+sin(phase*TAU)*.035*intensity
	while pose_history.size()<=lod:pose_history.append({})
	var history: Dictionary=pose_history[lod]
	for key in row:
		if key.begins_with("Anim_Leg") or key.begins_with("Anim_Gait"):continue
		var node: Node3D=row[key].node
		if transition_left>0 and history.has(key) and actor.state!="attack":
			node.transform=history[key].interpolate_with(node.transform,1-exp(-maxf(.001,dt)/.045))
		history[key]=node.transform
	if kind in ["slither","crawl"]:
		var segment:=0
		for key in row:
			if key.begins_with("Anim_Segment") or key.begins_with("Anim_Flex_Spine"):
				var node: Node3D=row[key].node
				var angle:=sin(phase*TAU-segment*.65)*intensity*(.12 if kind=="slither" else .035)
				node.transform=row[key].rest*Transform3D(Basis(Vector3.UP,angle),Vector3.ZERO)
				segment+=1
	Feet.pose(self,row,lod)

func take_footfall() -> Vector3:
	if footfalls.is_empty():return Vector3.INF
	var result: Vector3=footfalls[0];footfalls.clear();return result

static func sample(field: FrontierTerrainField,at: Vector3,reach: float) -> Dictionary:
	# A short density probe stays on the current cave floor instead of snapping to the surface above.
	var surface:=field.height(at.x,at.z)
	var span:=clampf(reach,.25,1.2)
	var top: float=at.y+span;var previous:=field.density_at_height(Vector3(at.x,top,at.z),surface)
	for i in 8:
		var bottom: float=at.y+span-float(i+1)*span*.25
		var value:=field.density_at_height(Vector3(at.x,bottom,at.z),surface)
		if previous<=0 and value>=0:
			for iteration in 7:
				var middle: float=(top+bottom)*.5
				if field.density_at_height(Vector3(at.x,middle,at.z),surface)>0:bottom=middle
				else:top=middle
			var point_value:=Vector3(at.x,(top+bottom)*.5+.008,at.z)
			return {"point":point_value,"normal":field.normal(point_value)}
		previous=value;top=bottom
	return {"point":at,"normal":Vector3.UP,"missing":true}

func bind_skin(lod: int) -> void:
	while skin_bindings.size()<=lod:skin_bindings.append({})
	var skeleton: Skeleton3D=actor.anatomical_skeletons[lod]
	if skeleton==null:return
	var row: Dictionary=actor.joints[lod]
	var skeleton_rest:=relative_rest(skeleton,actor.models[lod],row)
	for key in row:
		if not key.begins_with("Anim_Leg") and not key.begins_with("Anim_Gait"):continue
		var bone:=skeleton.find_bone(actor.definition.rig.hinges.get(key,""))
		if bone<0:continue
		var marker_rest:=relative_rest(row[key].node,actor.models[lod],row)
		skin_bindings[lod][bone]={"marker":key,"offset":marker_rest.affine_inverse()*skeleton_rest*skeleton.get_bone_global_rest(bone)}

static func relative_rest(node: Node3D,model: Node3D,row: Dictionary) -> Transform3D:
	var result:=Transform3D.IDENTITY
	var current: Node3D=node
	while current!=model and current!=null:
		result=(row[str(current.name)].rest if row.has(str(current.name)) else current.transform)*result
		current=current.get_parent() as Node3D
	return result

func skin(skeleton: Skeleton3D,row: Dictionary,lod: int) -> void:
	if not enabled or limbs.is_empty() or not actor.is_inside_tree():return
	if skin_bindings.size()<=lod:bind_skin(lod)
	var desired: Dictionary={}
	var inverse:=skeleton.global_transform.affine_inverse()
	for bone in skin_bindings[lod]:
		var entry: Dictionary=skin_bindings[lod][bone]
		desired[bone]=inverse*row[entry.marker].node.global_transform*entry.offset
	for bone in desired:
		var parent:=skeleton.get_bone_parent(bone)
		var parent_pose: Transform3D=desired.get(parent,skeleton.get_bone_global_pose(parent)) if parent>=0 else Transform3D.IDENTITY
		var local: Transform3D=parent_pose.affine_inverse()*desired[bone]
		skeleton.set_bone_pose_position(bone,local.origin)
		skeleton.set_bone_pose_rotation(bone,local.basis.orthonormalized().get_rotation_quaternion())
		skeleton.set_bone_pose_scale(bone,local.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
