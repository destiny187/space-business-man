extends RefCounted
## Contacts are shared by both LODs. Solvers preserve authored hip attachments.
static func vector(a: Array) -> Vector3:return Vector3(a[0],a[1],a[2])

static func rest_point(m: RefCounted,index: int) -> Vector3:
	var local: Vector3=vector(m.limbs[index].rest)
	local.y-=float(m.actor.definition.geometry.near.floor_y)
	return m.point+m.frame*(local*float(m.actor.base_scale))

static func ground(m: RefCounted,at: Vector3) -> Dictionary:
	if m.probe.is_valid():return m.probe.call(at,m.leg_length*float(m.actor.base_scale)*.75)
	return {"point":Vector3(at.x,m.point.y,at.z),"normal":m.frame.y}

static func update(m: RefCounted,delta: float) -> void:
	var scale_value: float=m.actor.base_scale
	var reach: float=m.leg_length*scale_value
	var frequency: float=maxf(.1,m.frequency)
	var active:=0
	for contact in m.contacts:
		if contact.swing:active+=1
	for i in m.limbs.size():
		var c: Dictionary=m.contacts[i]
		if m.released(i):c.ready=false;c.swing=false;continue
		var rest:=rest_point(m,i)
		var local_phase: float=m.phase+m.offset(i)
		var cycle:=floori(local_phase)
		var fraction:=fposmod(local_phase,1)
		if not c.ready:
			var hit:=ground(m,rest)
			c.position=hit.point;c.normal=hit.normal;c.ready=true;c.swing=false;c.cycle=cycle-1;c.refresh=0.0
		c.refresh=float(c.get("refresh",0))+delta
		# Re-probe a planted foot after terrain edits, without dragging it in X/Z.
		if not c.swing and c.refresh>.35:
			var hit:=ground(m,c.position)
			c.position.y=move_toward(float(c.position.y),float(hit.point.y),delta*2.0)
			c.normal=hit.normal;c.refresh=0.0
		var moving: bool=m.travel_speed>float(m.config().minimum_speed) and m.intensity>.05
		var stretched: bool=Vector2(c.position.x-rest.x,c.position.z-rest.z).length()>reach*(.35 if m.chains.has(m.limbs[i].hip) else .20)
		var due: bool=moving and fraction>=m.stance and int(c.cycle)!=cycle
		var max_airborne: int=m.limbs.size() if m.kind=="hop" or m.travel_speed>float(m.profile.run_speed)*scale_value else maxi(1,m.limbs.size()/2)
		if not c.swing and (due or stretched) and active<max_airborne:
			c.swing=true;c.cycle=cycle;c.start=c.position;c.elapsed=0.0
			c.duration=clampf((1-m.stance)/frequency,.075,.35) if moving else .14
			# Place ahead by the remaining swing travel plus half the following stance.
			var lead: float=float(c.duration)+float(m.stance)/frequency*.5
			var landing: Vector3=rest+m.velocity*lead
			if not moving:landing=rest
			var hit:=ground(m,landing);c.end=hit.point;c.end_normal=hit.normal
			var middle:=ground(m,(c.start+c.end)*.5)
			c.lift=maxf(reach*float(m.profile.lift),float(middle.point.y)-(float(c.start.y)+float(c.end.y))*.5+.02)
			c.lift=minf(float(c.lift),reach*.45)
			var neutral: Vector3=m.frame.inverse()*(rest-m.point)
			c.start_local=m.frame.inverse()*(c.start-m.point)
			# A discontinuous host snapshot may have moved past the previous foothold.
			# Released feet move with the body; never drag a stretched limb through a whole dash.
			c.start_local=neutral+(c.start_local-neutral).limit_length(reach*.40)
			c.end_local=m.frame.inverse()*(c.end-m.point-m.velocity*float(c.duration))
			active+=1
		if c.swing:
			if not moving:c.duration=minf(float(c.duration),maxf(float(c.elapsed)+.05,.16))
			c.elapsed+=delta
			var progress:=clampf(float(c.elapsed)/float(c.duration),0,1)
			if not moving:
				# A decelerating animal completes the lifted step instead of freezing a foot in air.
				c.end_local=c.end_local.lerp(m.frame.inverse()*(ground(m,rest).point-m.point),1-exp(-delta*12))
			var ease:=smoothstep(0.0,1.0,progress)
			c.position=m.point+m.frame*c.start_local.lerp(c.end_local,ease)+Vector3.UP*sin(progress*PI)*float(c.lift)
			c.normal=c.normal.lerp(c.end_normal,ease).normalized()
			if progress>=1:
				var landing:=ground(m,c.position)
				c.swing=false;c.position=landing.point;c.normal=landing.normal;c.end=c.position;active-=1
				if m.sound_left<=0 and moving:
					m.footfalls.append(c.position);m.sound_left=float(m.config().footstep_seconds)

static func preview_contact(m: RefCounted,index: int) -> Dictionary:
	var fraction: float=fposmod(m.phase+m.offset(index),1)
	var swing: bool=fraction>=m.stance
	var contact:=rest_point(m,index)
	var span: float=m.cycle_length*m.stance*m.intensity
	var lift:=0.0;var along:=0.0
	if swing:
		var p: float=(fraction-m.stance)/(1-m.stance)
		along=lerpf(-span*.5,span*.5,smoothstep(0.0,1.0,p))
		lift=sin(p*PI)*m.leg_length*float(m.actor.base_scale)*float(m.profile.lift)*m.intensity
	else:along=span*(.5-fraction/m.stance)
	contact+=m.frame.z*along;contact.y=m.point.y+lift
	return {"ready":true,"position":contact,"normal":m.frame.y,"swing":swing}

static func pose(m: RefCounted,row: Dictionary,lod: int) -> void:
	for i in m.limbs.size():
		var limb: Dictionary=m.limbs[i]
		if not row.has(limb.hip) or m.released(i):continue
		var c: Dictionary=m.contacts[i] if m.driven else preview_contact(m,i)
		if not c.ready:continue
		if m.chains.has(limb.hip):solve_chain(m,row,limb,m.chains[limb.hip],c)
		else:solve_single(m,row,limb,c)
		if lod==0:
			var endpoint: Node3D=row[m.chains[limb.hip].ankle].node if m.chains.has(limb.hip) else row[limb.hip].node
			c.error=endpoint.to_global(vector(limb.tip)).distance_to(c.position)

static func solve_chain(m: RefCounted,row: Dictionary,limb: Dictionary,chain: Dictionary,c: Dictionary) -> void:
	var hip: Node3D=row[chain.hip].node
	var knee: Node3D=row[chain.knee].node
	var ankle: Node3D=row[chain.ankle].node
	var rest: Transform3D=hip.get_parent().global_transform*row[chain.hip].rest
	var normal: Vector3=c.normal.normalized()
	var side: Vector3=normal.cross(m.frame.z).normalized()
	if side.length_squared()<.5:side=m.frame.x
	var sole_basis:=Basis(side,normal,side.cross(normal).normalized())
	var ankle_goal: Vector3=c.position-sole_basis*(vector(limb.tip)*float(m.actor.base_scale))
	var destination:=rest.affine_inverse()*ankle_goal
	var upper:=vector(chain.upper);var lower:=vector(chain.lower)
	var a:=upper.length();var b:=lower.length()
	var distance:=clampf(destination.length(),absf(a-b)+.001,a+b-.001)
	var direction:=destination.normalized();destination=direction*distance
	var along: float=(a*a-b*b+distance*distance)/(2*distance)
	var bend:=upper-direction*upper.dot(direction)
	if bend.length_squared()<.00001:bend=direction.cross(Vector3.RIGHT)
	bend=bend.normalized()
	var knee_goal:=direction*along+bend*sqrt(maxf(0,a*a-along*along))
	var hip_rotation:=Quaternion(upper.normalized(),knee_goal.normalized())
	var lower_rotation:=Quaternion(lower.normalized(),(destination-knee_goal).normalized())
	hip.transform=row[chain.hip].rest*Transform3D(Basis(hip_rotation),Vector3.ZERO)
	knee.transform=row[chain.knee].rest*Transform3D(Basis(hip_rotation.inverse()*lower_rotation),Vector3.ZERO)
	var ankle_rest: Transform3D=ankle.get_parent().global_transform*row[chain.ankle].rest
	ankle.transform=row[chain.ankle].rest*Transform3D(ankle_rest.basis.orthonormalized().inverse()*sole_basis,Vector3.ZERO)

static func solve_single(m: RefCounted,row: Dictionary,limb: Dictionary,c: Dictionary) -> void:
	var hip: Node3D=row[limb.hip].node
	var rest: Transform3D=hip.get_parent().global_transform*row[limb.hip].rest
	var tip:=vector(limb.tip);var target: Vector3=rest.affine_inverse()*c.position
	if tip.length()<.001 or target.length()<.001:return
	var axis:=tip.normalized()
	var rotation:=Quaternion(axis,target.normalized())
	# One-hinge legacy limbs retain their root, with bounded, shear-free compliance.
	# No detached vertical translation of an entire leg and no fabricated knee joint.
	var ratio:=clampf(target.length()/tip.length(),float(m.config().single_limb_compression),float(m.config().single_limb_extension))
	var stretch:=Basis.from_scale(Vector3.ONE*ratio)
	hip.transform=row[limb.hip].rest*Transform3D(Basis(rotation)*stretch,Vector3.ZERO)
