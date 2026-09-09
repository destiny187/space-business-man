"""Illuti combat chassis. Preserve the original metre envelope and animation pivots."""
def build_robot(p, api):
    import bmesh
    bpy=api['bpy']; math=api['math']; ink=api['ink']
    box=api['box']; cylinder=api['cylinder']; empty=api['empty']; torus=api['torus']; mat=api['mat']; finish=api['finish']
    dark=api['dark']; steel=api['steel']; orange=api['orange']; red=api['red']; screen=api['screen']
    armor=mat('Illuti graphite armour',(.075,.095,.105),.38,.43)
    edge=mat('Illuti worn armour',(.22,.255,.26),.5,.4)
    marking=mat('Illuti oxide markings',(.27,.037,.018),.18,.57)
    def plate(name,points,front,back,m,parent):
        n=len(points);verts=[(x,y,z) for y in [front,back] for x,z in points]
        faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
        o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
        return finish(o,name,m,parent,.025)
    # Wide planted stance, narrow ankles and long articulated shins.
    for s in [-1,1]:
        x=s*.48
        box('Split magnetic heel',(x,.13,.14),(.52,.58,.28),dark,p,.045)
        plate('Wedge sabaton',[(x-.29,.06),(x+.29,.06),(x+.25,.27),(x-.21,.34)],-.61,.15,armor,p)
        for dx in [-.17,.17]:box('Traction toe',(x+dx,-.49,.10),(.085,.38,.12),steel,p,.018)
        leg=empty('Anim_Leg_'+str(s),(x,0,.3),p)
        cylinder('Shin actuator',(x,.03,.29),(x,.03,.99),.13,dark,leg)
        cylinder('Exposed return piston',(x+s*.16,.11,.35),(x+s*.16,.11,.94),.045,steel,leg)
        plate('Tapered shin shield',[(x-.16,.35),(x+.16,.35),(x+.25,.91),(x+.17,1.08),(x-.22,.96)],-.27,-.02,armor,leg)
        box('Shin identifier',(x,-.298,.77),(.22,.035,.09),marking,leg,.012)
        cylinder('Knee bearing',(x-.23,0,1.03),(x+.23,0,1.03),.19,steel,leg)
        plate('Angular kneecap',[(x-.22,1.00),(x, .87),(x+.22,1.00),(x+.15,1.21),(x-.15,1.21)],-.31,-.07,edge,leg)
        cylinder('Load bearing thigh',(x,.05,1.1),(s*.30,.05,1.48),.17,dark,leg)
        box('Thigh guard',(x*.85,-.08,1.29),(.3,.32,.40),armor,leg,.035,rot=(0,s*-.16,0))
    torso=empty('Anim_Torso',(0,0,1.4),p)
    plate('Armoured pelvis',[(-.42,1.3),(.42,1.3),(.51,1.55),(.34,1.64),(-.34,1.64),(-.51,1.55)],-.28,.29,armor,torso)
    for z in [1.57,1.67,1.77]:box('Abdominal flexure',(0,-.31,z),(.52,.13,.045),steel,torso,.012)
    # Chest tapers down. Head sits behind raised collar, not on a toy-like neck.
    plate('Reactor load frame',[(-.36,1.69),(.36,1.69),(.71,2.29),(.50,2.48),(-.50,2.48),(-.71,2.29)],-.22,.38,dark,torso)
    for s in [-1,1]:
        pts=[(s*.08,2.17),(s*.30,1.8),(s*.64,1.97),(s*.79,2.37),(s*.43,2.48),(s*.08,2.35)]
        plate('Swept breastplate',pts,-.47,-.19,armor,torso)
        plate('Chest ridge',[(s*.13,2.31),(s*.51,2.38),(s*.68,2.31),(s*.48,2.27)],-.502,-.47,edge,torso)
        box('Raised neck guard',(s*.34,-.01,2.51),(.15,.59,.34),edge,torso,.035,rot=(0,s*.22,0))
        cylinder('Rear coolant loop',(s*.42,.38,1.62),(s*.53,.40,2.38),.065,steel,torso)
    # Keep the weak-point location used by host aim validation.
    torus('Reactor aperture',(0,-.43,1.98),.205,.055,steel,torso,rot=(math.pi/2,0,0))
    weak=empty('Anim_Weak',(0,0,0),torso)
    cylinder('Exposed reactor',(0,-.45,1.98),(0,-.52,1.98),.17,screen,weak)
    plate('Predator sensor hood',[(-.28,2.49),(.28,2.49),(.34,2.74),(.22,2.85),(-.22,2.85),(-.34,2.74)],-.37,.13,armor,torso)
    plate('Recessed optic mask',[(-.26,2.58),(0,2.50),(.26,2.58),(.25,2.72),(-.25,2.72)],-.394,-.37,dark,torso)
    for s in [-1,1]:
        plate('Slanted threat optic',[(s*.035,2.615),(s*.235,2.69),(s*.235,2.645),(s*.035,2.58)],-.411,-.396,red,torso)
    plate('Brow overhang',[(-.30,2.74),(0,2.66),(.30,2.74),(.21,2.80),(-.21,2.80)],-.44,-.2,edge,torso)
    plate('Sensor jaw',[(-.22,2.57),(0,2.43),(.22,2.57),(.13,2.59),(0,2.53),(-.13,2.59)],-.42,-.27,armor,torso)
    box('Rear power cassette',(0,.46,2.13),(.68,.3,.62),armor,torso,.065)
    for z in [1.97,2.10,2.23]:box('Rear radiator',(0,.635,z),(.53,.055,.047),steel,torso,.012)
    for s in [-1,1]:
        arm=empty('Anim_Arm_'+str(s),(s*.82,0,2.25),torso)
        cylinder('Shoulder bearing',(s*.62,0,2.3),(s*1.05,0,2.3),.205,steel,arm)
        plate('Overhanging shoulder armour',[(s*.67,2.32),(s*1.19,2.15),(s*1.22,2.51),(s*.91,2.7),(s*.67,2.62)],-.32,.35,armor,arm)
        plate('Shoulder red band',[(s*.76,2.48),(s*1.11,2.35),(s*1.11,2.43),(s*.76,2.56)],-.351,-.32,marking,arm)
        cylinder('Upper arm ram',(s*.97,0,2.19),(s*1.02,0,1.71),.12,dark,arm)
        cylinder('Arm hydraulic',(s*1.12,.07,2.17),(s*1.13,.07,1.70),.048,steel,arm)
        cylinder('Elbow axle',(s*.84,0,1.69),(s*1.16,0,1.69),.16,steel,arm)
        if s==1:
            box('Integral weapon receiver',(.99,-.22,1.56),(.49,.81,.47),armor,arm,.06)
            box('Recoil rail',(.99,-.29,1.83),(.21,.73,.11),edge,arm,.018)
            for z in [1.47,1.66]:
                cylinder('Pulse accelerator',(.99,-.46,z),(.99,-1.19,z),.105,dark,arm)
                torus('Muzzle armour',(.99,-1.16,z),.11,.037,steel,arm,rot=(math.pi/2,0,0))
                cylinder('Muzzle recess',(.99,-1.193,z),(.99,-1.202,z),.069,dark,arm)
            for y in [-.36,-.54,-.72]:box('Weapon cooling block',(1.27,y,1.59),(.10,.10,.26),edge,arm,.018)
            box('Weapon caution stripe',(.99,-.73,1.86),(.15,.18,.025),orange,arm,.005)
        else:
            plate('Breach gauntlet',[(-1.24,1.29),(-.84,1.24),(-.83,1.75),(-1.18,1.88)],-.35,.20,armor,arm)
            for dx in [-.13,.13]:
                x=-1.01+dx
                plate('Two stage grappling talon',[(x-.055,1.3),(x+.055,1.3),(x+.06,1.00),(x+.00,.87),(x-.075,1.06)],-.38,-.19,steel,arm)
            box('Gauntlet sensor',(-1.02,-.376,1.58),(.2,.032,.043),red,arm,.01)
    # Raised, sparse manufacturer's serial plate; no friendly chest screen.
    box('Serial plaque',(-.48,-.513,2.13),(.21,.024,.14),marking,torso,.012)
    return p
