extends RefCounted
## Display-only locomotion: measured world travel, planted feet, anatomy-preserving two-bone IK.
var root: Node3D
var model: Node3D
var cfg: Dictionary
var settings: Dictionary
var skeleton: Skeleton3D
var limbs: Array[Dictionary]=[]
var velocity:=Vector3.ZERO
var phase:=.62
var snapshot: Vector3
var snapshot_clock:=-1.0
var since_snapshot:=0.0
var last_yaw:=0.0
var moving:=false
var travel:=0.0
var grounded: Callable
var body_drop:=0.0
var model_rest_y:=0.0

func configure(nodes: Dictionary,row: Dictionary,sampler: Callable) -> void:
 root=nodes.root;model=nodes.main;cfg=FrontierCooperTechSquads.spec(row);settings=FrontierCooperTechSquads.config().motion;grounded=sampler
 snapshot=root.global_position;last_yaw=root.rotation.y;model_rest_y=model.position.y
 if row.robot_role=="sentry":model.rotation.y=PI
 var skeletons:=model.find_children("*","Skeleton3D",true,false)
 if not skeletons.is_empty():skeleton=skeletons[0]
 if skeleton!=null:
  skeleton.reset_bone_poses();skeleton.force_update_all_bone_transforms()
  for i in skeleton.get_bone_count():
   var name:=str(skeleton.get_bone_name(i))
   if name.begins_with("hip_"):
    var suffix:=name.trim_prefix("hip_")
    var knee:=skeleton.find_bone("knee_"+suffix);var foot:=skeleton.find_bone("foot_"+suffix)
    if knee>=0 and foot>=0:add_limb(i,knee,foot,suffix)
 else:
  for node in nodes.parts:
   if not str(node.name).begins_with("Anim_Hip_"):continue
   var suffix:=str(node.name).trim_prefix("Anim_Hip_")
   var knee:=model.find_child("Anim_Knee_"+suffix,true,false);var foot:=model.find_child("Anim_Foot_"+suffix,true,false)
   if knee!=null and foot!=null:add_limb(node,knee,foot,suffix)

func pose(joint: Variant) -> Transform3D:
 return skeleton.global_transform*skeleton.get_bone_global_pose(joint) if skeleton!=null else joint.global_transform
func put(joint: Variant,value: Transform3D) -> void:
 if skeleton==null:joint.global_transform=value;return
 var desired:=skeleton.global_transform.affine_inverse()*value
 var parent:=skeleton.get_bone_parent(joint)
 var local: Transform3D=skeleton.get_bone_global_pose(parent).affine_inverse()*desired if parent>=0 else desired
 skeleton.set_bone_pose_position(joint,local.origin)
 skeleton.set_bone_pose_rotation(joint,local.basis.orthonormalized().get_rotation_quaternion())
 skeleton.set_bone_pose_scale(joint,local.basis.get_scale())
 skeleton.force_update_all_bone_transforms()
func add_limb(hip: Variant,knee: Variant,foot: Variant,suffix: String) -> void:
 var h:=pose(hip);var k:=pose(knee);var f:=pose(foot)
 var rest:=root.to_local(f.origin)
 var side: int=int(suffix.split("_")[0]);var fore: int=int(suffix.split("_")[1]) if suffix.contains("_") else 1
 var offset:=.5 if side*fore<0 else 0.0
 var limb: Dictionary={"hip":hip,"knee":knee,"foot":foot,"rest":rest,"sole":rest.y,"basis":root.global_basis.inverse()*f.basis,"upper":h.origin.distance_to(k.origin),"lower":k.origin.distance_to(f.origin),"bend":root.global_basis.inverse()*(k.origin-h.origin),"offset":offset,"position":f.origin,"orientation":f.basis,"swing":false,"elapsed":0.0,"duration":.2,"last_cycle":-1000,"start":f.origin,"target":f.origin,"active":false}
 limb.hip_rest=skeleton.get_bone_pose(hip) if skeleton!=null else hip.transform
 limb.knee_rest=skeleton.get_bone_pose(knee) if skeleton!=null else knee.transform
 limb.foot_rest=skeleton.get_bone_pose(foot) if skeleton!=null else foot.transform
 limbs.append(limb)

func update_position(row: Dictionary,delta: float,stopped: bool) -> void:
 if stopped:return
 var dt:=minf(delta,.1);var before:=root.global_position
 var now:=FrontierCrewWorld.vector(row.position)
 var clock: float=row.get("motion_clock",row.get("age",0.0))
 if now!=snapshot or clock!=snapshot_clock:
  since_snapshot=0.0;snapshot=now;snapshot_clock=clock
 else:since_snapshot+=dt
 var feed:=FrontierCrewWorld.vector(row.get("move_velocity",[0,0,0]))
 if row.hp<=0 or row.phase in ["idle","waking","destroyed"]:feed=Vector3.ZERO
 var target:=snapshot+feed*minf(since_snapshot,float(settings.prediction_seconds))
 if before.distance_to(target)>maxf(5.0,float(cfg.speed)):
  root.global_position=target;velocity=Vector3.ZERO
  for limb in limbs:limb.active=false
 else:
  var correction: Vector3=(target-before);correction.y=0
  var requested: Vector3=(feed+correction*3.0).limit_length(float(cfg.speed))
  velocity=velocity.move_toward(requested,float(cfg.acceleration)*dt)
  if feed.length()<.01 and correction.length()<.025 and velocity.length()<.08:velocity=Vector3.ZERO
  root.global_position=before+velocity*dt
 # Terrain support is sampled at the displayed position; no floating chord on a slope.
 if grounded.is_valid():root.global_position.y=float(grounded.call(root.global_position).height)
 var change:=wrapf(float(row.yaw)-root.rotation.y,-PI,PI)
 root.rotation.y+=clampf(change,-float(settings.turn_radians)*dt,float(settings.turn_radians)*dt)
 velocity=(root.global_position-before)/maxf(.001,dt);velocity.y=0
 travel=velocity.length()*dt
 moving=velocity.length()>float(settings.minimum_speed) and row.hp>0 and row.phase not in ["idle","waking","destroyed"]

func restore(limb: Dictionary) -> void:
 for name in ["hip","knee","foot"]:
  if skeleton!=null:
   var t: Transform3D=limb[name+"_rest"]
   skeleton.set_bone_pose_position(limb[name],t.origin);skeleton.set_bone_pose_rotation(limb[name],t.basis.get_rotation_quaternion())
  else:limb[name].transform=limb[name+"_rest"]
 if skeleton!=null:skeleton.force_update_all_bone_transforms()
func ground(at: Vector3,sole: float) -> Vector3:
 if grounded.is_valid():at.y=float(grounded.call(at).height)+sole
 else:at.y=root.global_position.y+sole
 return at
func feet(row: Dictionary,delta: float,stopped: bool) -> void:
 if stopped:return
 if row.hp<=0 or row.phase in ["idle","waking","destroyed"]:
  for limb in limbs:limb.active=false
  return
 model.position.y=model_rest_y
 var speed:=velocity.length();var ratio:=clampf(speed/maxf(.01,float(cfg.speed)),0,1)
 # One calibrated stride at playback rate 1.0; actual travel sets cadence.
 var local_direction:=velocity.normalized().rotated(Vector3.UP,-root.rotation.y)
 var gait_factor:=lerpf(1.0,float(settings.side_stride_factor),absf(local_direction.x))
 if local_direction.z>0:gait_factor*=lerpf(1.0,float(settings.back_stride_factor),local_direction.z)
 var stride: float=float(cfg.stride)*gait_factor
 var stance:=.62
 var yaw_rate:=wrapf(root.rotation.y-last_yaw,-PI,PI)/maxf(delta,.001)
 var turning:=absf(yaw_rate)*delta;last_yaw=root.rotation.y
 var foot_radius:=float(cfg.radius)
 for limb in limbs:foot_radius=maxf(foot_radius,Vector2(limb.rest.x,limb.rest.z).length())
 var angular_speed:=turning*foot_radius/maxf(delta,.001)
 speed=maxf(speed,angular_speed)
 # At a crawl, shorten the step as well as slowing cadence so support legs stay within reach.
 var nominal:=float(cfg.stride)/float(cfg.gait_seconds)
 stride*=clampf(sqrt(speed/maxf(.01,nominal)),.2,1.0)
 phase+=maxf(travel,turning*foot_radius)/maxf(.1,stride)
 for limb in limbs:
  restore(limb)
  var neutral:=ground(root.to_global(limb.rest),float(limb.sole))
  if not limb.active:
   limb.position=neutral;limb.start=neutral;limb.target=neutral;limb.active=true;limb.swing=false;limb.last_cycle=floori(phase+float(limb.offset))-1;limb.orientation=root.global_basis*Basis(limb.basis)
  var fraction:=fposmod(phase+float(limb.offset),1.0);var cycle:=floori(phase+float(limb.offset))
  var resting_step: bool=not moving and angular_speed<float(settings.minimum_speed) and Vector3(limb.position).distance_to(neutral)>.12
  if not limb.swing and not limbs.any(func(other):return other.swing and other.offset!=limb.offset) and ((fraction>=stance and int(limb.last_cycle)!=cycle and (moving or turning>.001)) or resting_step):
   limb.swing=true;limb.elapsed=0.0;limb.start=limb.position;limb.last_cycle=cycle
   limb.duration=clampf((1-stance)*stride/maxf(.4,speed),float(cfg.gait_seconds)*(1-stance)/float(cfg.max_gait_rate),.6)
   limb.target=landing_point(limb,float(limb.duration)+stride/maxf(.4,speed)*stance*.5,yaw_rate)
  if limb.swing:
   limb.elapsed+=delta
   var desired_basis: Basis=root.global_basis*Basis(limb.basis)
   limb.orientation=Basis(Basis(limb.orientation).orthonormalized().get_rotation_quaternion().slerp(desired_basis.orthonormalized().get_rotation_quaternion(),1-exp(-delta*18)))
   var t:=clampf(float(limb.elapsed)/float(limb.duration),0,1)
   # Re-evaluate landing on turns without moving a planted foot.
   # Predict only the remaining swing, easing retargeting out before contact.
   var landing:=landing_point(limb,float(limb.duration)*(1-t)+stride/maxf(.4,speed)*stance*.5,yaw_rate)
   limb.target=Vector3(limb.target).lerp(landing,(1-exp(-delta*5))*(1-smoothstep(.55,1,t)))
   limb.position=Vector3(limb.start).lerp(limb.target,smoothstep(0,1,t))+Vector3.UP*sin(t*PI)*float(cfg.foot_lift)*lerpf(.45,1.0,ratio)
   if t>=1:limb.swing=false;limb.position=ground(limb.target,float(limb.sole))
 # Preserve contact when a planted leg approaches full extension during a turn.
 # This is a small chassis height adjustment, not a change to host movement or limb length.
 var required_drop:=0.0
 for limb in limbs:
  if limb.swing:continue
  var hip:=pose(limb.hip).origin;var goal: Vector3=limb.position
  var horizontal:=Vector2(hip.x-goal.x,hip.z-goal.z).length_squared()
  var reach: float=(float(limb.upper)+float(limb.lower))*.995
  required_drop=maxf(required_drop,hip.y-goal.y-sqrt(maxf(.001,reach*reach-horizontal)))
 body_drop=move_toward(body_drop,clampf(required_drop,0,.14),delta*.9)
 model.position.y=model_rest_y-body_drop
 for limb in limbs:solve(limb,limb.position)

func landing_point(limb: Dictionary,lead: float,yaw_rate: float) -> Vector3:
 var local:=Vector3(limb.rest).rotated(Vector3.UP,yaw_rate*lead)
 return ground(root.to_global(local)+velocity*lead,float(limb.sole))

func solve(limb: Dictionary,goal: Vector3) -> void:
 var h:=pose(limb.hip);var k:=pose(limb.knee);var f:=pose(limb.foot)
 var a: float=limb.upper;var b: float=limb.lower
 var delta:=goal-h.origin;var distance:=clampf(delta.length(),absf(a-b)+.001,(a+b)*.999)
 var axis:=delta.normalized();var target:=h.origin+axis*distance
 var bend: Vector3=root.global_basis*Vector3(limb.bend)
 bend-=axis*bend.dot(axis)
 if bend.length()<.001:bend=root.global_basis.z-axis*root.global_basis.z.dot(axis)
 var along: float=(a*a-b*b+distance*distance)/(2*distance)
 var knee:=h.origin+axis*along+bend.normalized()*sqrt(maxf(0,a*a-along*along))
 h.basis=Basis(Quaternion((k.origin-h.origin).normalized(),(knee-h.origin).normalized()))*h.basis;put(limb.hip,h)
 k=pose(limb.knee);f=pose(limb.foot)
 k.basis=Basis(Quaternion((f.origin-k.origin).normalized(),(target-k.origin).normalized()))*k.basis;put(limb.knee,k)
 f=pose(limb.foot);f.basis=limb.orientation;put(limb.foot,f)
