extends "res://tests/render_coopertech_locomotion.gd"
func run() -> void:
 var failed:=false
 for i in 3:
  var p:=panel(["sentry","bastion","raptor"][i],i)
  var worst:=0.0
  for frame in 600:
   p.at+=Vector3.FORWARD*.12/60.0
   p.row.position=FrontierSpaceCombat.arr(p.at);p.row.move_velocity=[0,0,-.12];p.row.motion_clock=float(frame)/60
   Driver.update(p.view,p.row,p.nodes,1.0/60,false)
   var motion: RefCounted=p.nodes.locomotion
   for limb in motion.limbs:
    if not limb.swing:worst=maxf(worst,motion.pose(limb.foot).origin.distance_to(limb.position))
  print("SLOW_GAIT ",p.row.robot_role," error_m ",worst)
  failed=failed or worst>.01
  p.view.attack_effects.free();p.view.free()
 quit(1 if failed else 0)
