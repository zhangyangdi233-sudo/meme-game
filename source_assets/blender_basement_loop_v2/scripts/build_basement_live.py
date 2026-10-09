"""Run named stages in the visible Blender MCP session. Never clears user data."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector, Quaternion
OUT = Path(r'D:/aphasia/outputs/blender_basement_loop_v2')
OUT.mkdir(parents=True, exist_ok=True)
COL = {}
M = {}
scene = None

def collection(name):
    if name not in COL:
        COL[name] = bpy.data.collections.new(name)
        scene.collection.children.link(COL[name])
    return COL[name]

def box(name, loc, size, mat=None, group='01_Room_Shell', bevel=0, collision=False):
    sx,sy,sz=[v/2 for v in size]
    vs=[(-sx,-sy,-sz),(sx,-sy,-sz),(sx,sy,-sz),(-sx,sy,-sz),(-sx,-sy,sz),(sx,-sy,sz),(sx,sy,sz),(-sx,sy,sz)]
    fs=[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
    me=bpy.data.meshes.new(name); me.from_pydata(vs,[],fs);me.update()
    ob=bpy.data.objects.new(name,me);collection(group).objects.link(ob);ob.location=loc
    if mat:me.materials.append(mat)
    uv=me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        axis=max(range(3),key=lambda i:abs(p.normal[i]))
        for li in p.loop_indices:
            v=me.vertices[me.loops[li].vertex_index].co
            q=(v.y,v.z) if axis==0 else ((v.x,v.z) if axis==1 else (v.x,v.y))
            uv.data[li].uv=(q[0]*.65,q[1]*.65)
    if bevel:
        md=ob.modifiers.new('Soft manufactured edges','BEVEL');md.width=bevel;md.segments=3
        ob.modifiers.new('Weighted surface normals','WEIGHTED_NORMAL')
    if collision:
        proxy=box(name+'-colonly',loc,size,group='90_Static_Collision')
        proxy.hide_render=True;proxy.display_type='WIRE';proxy.hide_set(True)
    return ob

def bounds(name,x0,x1,y0,y1,z0,z1,mat=None,group='01_Room_Shell',collision=True):
    return box(name,((x0+x1)/2,(y0+y1)/2,(z0+z1)/2),(x1-x0,y1-y0,z1-z0),mat,group,collision=collision)

def empty(name,loc,group='80_Game_Anchors',parent=None):
    ob=bpy.data.objects.new(name,None);collection(group).objects.link(ob);ob.location=loc
    ob.empty_display_size=.20
    if parent:ob.parent=parent
    return ob

def lathe(name,loc,profile,mat,group='02_Stairs_Detail',n=16):
    vs=[(r*math.cos(i*2*math.pi/n),r*math.sin(i*2*math.pi/n),z) for z,r in profile for i in range(n)]
    fs=[]
    for j in range(len(profile)-1):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    fs.extend([tuple(range(n-1,-1,-1)),tuple((len(profile)-1)*n+i for i in range(n))])
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
    ob=bpy.data.objects.new(name,me);collection(group).objects.link(ob);ob.location=loc;me.materials.append(mat)
    for p in me.polygons:p.use_smooth=len(p.vertices)==4
    return ob

def beam(name,a,b,r,mat,group='02_Stairs_Detail'):
    a,b=Vector(a),Vector(b)
    ob=lathe(name,a,[(0,r),((b-a).length,r)],mat,group)
    ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return ob

def camera(name,loc,target,lens=26):
    data=bpy.data.cameras.new(name);data.lens=lens;data.clip_start=.05;data.clip_end=120
    ob=bpy.data.objects.new(name,data);collection('70_Preview_Cameras').objects.link(ob);ob.location=loc
    ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler();return ob

def viewport(view='cutaway'):
    # Hide only in viewport, never in final rendered scene or exported geometry.
    for ob in scene.objects:
        if ob.name.endswith('-colonly'):ob.hide_set(True)
        elif ob.get('cutaway_hide'):ob.hide_set(view=='cutaway')
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                sp=area.spaces.active;sp.overlay.show_overlays=False
                if view=='cutaway':
                    sp.region_3d.view_perspective='PERSP'
                    sp.region_3d.view_location=(0,0,1.2);sp.region_3d.view_distance=13
                    sp.region_3d.view_rotation=Vector((8,-11,10)).to_track_quat('Z','Y')
                    sp.shading.type='MATERIAL'
                else:
                    sp.region_3d.view_perspective='CAMERA'
                    sp.region_3d.view_camera_zoom=5

def stage_shell():
    global scene,M
    scene=bpy.data.scenes.new('Aphasia_Basement_Loop_v2');bpy.context.window.scene=scene
    scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    names={'wall':'PBR_WarmAgedPlaster','carpet':'PBR_TaupeLoopCarpet','ceiling':'PBR_PopcornCeiling','cream':'Paint_OffWhite','wood':'PBR_AgedWalnut','metal':'Metal_AgedBrass','black':'Plastic_Charcoal','bulb':'Glass_OpalBulb'}
    M={k:bpy.data.materials[v] for k,v in names.items()}
    # Main room rectangle, with a right-hand opening in the back partition.
    bounds('Room_Floor',-3.28,3.28,-4.28,4.28,-.20,0,M['carpet'])
    bounds('Wall_Front',-3.36,3.36,-4.36,-4.20,0,2.75,M['wall'])['cutaway_hide']=True
    bounds('Wall_East',3.20,3.36,-4.20,4.20,0,2.75,M['wall'])['cutaway_hide']=True
    bounds('Wall_Rear',-3.36,3.36,4.20,4.36,0,2.75,M['wall'])
    bounds('Wall_West_Main',-3.36,-3.20,-4.20,1.34,0,2.75,M['wall'])
    bounds('Wall_West_BelowEntry',-3.36,-3.20,1.34,2.40,0,2.70,M['wall'])
    bounds('Wall_West_BetweenDoors',-3.36,-3.20,2.40,2.90,0,2.75,M['wall'])
    bounds('Wall_West_ExitEnd',-3.36,-3.20,3.96,4.20,0,2.75,M['wall'])
    bounds('Exit_Lintel',-3.36,-3.20,2.90,3.96,2.20,2.75,M['wall'])
    bounds('NPC_Partition',-3.20,1.65,2.42,2.58,0,2.75,M['wall'])
    bounds('Stairwell_West',-3.36,-3.20,-2.60,1.34,2.75,5.15,M['wall'])
    bounds('Stairwell_EntryLintel',-3.36,-3.20,1.34,2.40,4.90,5.15,M['wall'])
    bounds('Stairwell_RearPier',-3.36,-3.20,2.40,2.58,2.75,5.15,M['wall'])
    bounds('Stairwell_UpperEast',-1.85,-1.69,-2.60,2.58,2.75,5.15,M['wall'])['cutaway_hide']=True
    bounds('Stairwell_UpperRear',-3.2,-1.69,2.42,2.58,2.75,5.15,M['wall'])
    bounds('Stairwell_UpperFront',-3.36,-1.69,-2.76,-2.60,2.75,5.15,M['wall'])['cutaway_hide']=True
    for name,x0,x1,y0,y1,z in [('Ceiling_Main',-1.69,3.36,-4.36,4.36,2.75),('Ceiling_FrontLeft',-3.36,-1.69,-4.36,-2.60,2.75),('Ceiling_RearLeft',-3.36,-1.69,2.58,4.36,2.75),('Ceiling_Stairwell',-3.36,-1.69,-2.60,2.58,5.15)]:
        bounds(name,x0,x1,y0,y1,z,z+.14,M['ceiling'],'03_Ceilings')['cutaway_hide']=True
    # Upper and lower doorway pockets create usable thresholds outside the room.
    for prefix,y0,y1,z in [('Entry',1.34,2.40,2.70),('Exit',2.90,3.96,0)]:
        bounds(prefix+'_VestibuleFloor',-4.42,-3.20,y0-.08,y1+.08,z-.16,z,M['carpet'])
        bounds(prefix+'_VestibuleBack',-4.58,-4.42,y0-.16,y1+.16,z,z+2.45,M['wall'])
        for yy in [y0-.08,y1+.08]:box(prefix+'_VestibuleSide',(-3.89,yy,z+1.225),(1.22,.16,2.45),M['wall'],collision=True)
        bounds(prefix+'_VestibuleCeiling',-4.58,-3.2,y0-.16,y1+.16,z+2.45,z+2.59,M['ceiling'],'03_Ceilings')['cutaway_hide']=True
    # Fifteen individually editable steps. Collision uses one smooth wedge.
    for i in range(15):
        y=-2.60+(i+.5)*.28; z=(i+1)*.18
        box('Stair_Step_%02d'%(i+1),(-2.495,y,z/2),(1.29,.28,z),M['cream'],'02_Stairs_Detail')
        box('Carpet_Tread_%02d'%(i+1),(-2.495,y-.01,z+.010),(1.20,.30,.020),M['carpet'],'02_Stairs_Detail',.008)
        box('Carpet_Riser_%02d'%(i+1),(-2.495,y-.146,z-.09),(1.20,.016,.18),M['carpet'],'02_Stairs_Detail')
    bounds('Stair_UpperLanding',-3.20,-1.85,1.60,2.42,2.52,2.70,M['carpet'],'02_Stairs_Detail')
    xa,xb,ya,yb,z=-3.14,-1.85,-2.74,1.60,2.72
    vs=[(xa,ya,0),(xb,ya,0),(xa,yb,0),(xb,yb,0),(xa,yb,z),(xb,yb,z)]
    fs=[(0,2,3,1),(2,4,5,3),(0,1,5,4),(0,4,2),(1,3,5)]
    me=bpy.data.meshes.new('Stair_WalkRamp-colonly');me.from_pydata(vs,[],fs);me.update()
    ramp=bpy.data.objects.new('Stair_WalkRamp-colonly',me);collection('90_Static_Collision').objects.link(ramp);ramp.hide_render=True;ramp.display_type='WIRE'
    # Entry and game markers exactly match asset_contract.json.
    contract=json.loads((OUT/'asset_contract.json').read_text(encoding='utf-8'))
    for name,d in contract['anchors'].items():
        ob=empty(name,d['position'])
        ob['game_anchor']=True
        if 'forward_blender' in d:ob['forward_blender']=d['forward_blender']
    scene.camera=camera('View_Basement_Entrance',(-2.5,1.42,4.30),(-1.6,-3.0,.85),23)
    camera('View_TV_Stairs',(1.90,-3.30,1.66),(-2.10,.65,1.55),24)
    camera('View_RightPassage',(2.42,-1.80,1.65),(1.90,3.58,1.45),25)
    camera('View_NPC_Exit',(2.55,3.35,1.65),(-2.75,3.39,1.25),26)
    world=bpy.data.worlds.new('Basement_BlackWorld');world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.06,.07,.10,1);bg.inputs[1].default_value=.08;scene.world=world
    try:scene.render.engine='CYCLES'
    except TypeError:pass
    scene.cycles.samples=48;scene.cycles.use_denoising=True
    scene.render.resolution_x=1440;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    viewport('cutaway');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Basement_Loop_v2.blend'))
    print('STAGE 1: approved rectangular shell, stairwell, real doorway pockets, right-hand passage. Objects',len(scene.objects))

def stage_details():
    profile=[(0,.022),(.1,.022),(.14,.029),(.19,.015),(.32,.024),(.41,.015),(.46,.027),(.53,.014),(.86,.014),(.92,.023),(.96,.023)]
    for i in range(24):
        y=-2.60+i*4.2/23;z=(y+2.60)/4.20*2.70+.04
        lathe('White_Spindle_%02d'%i,(-1.83,y,z),profile,M['cream'])
    for y,z in [(-2.62,0),(1.60,2.70),(2.36,2.70)]:
        box('Newel_Post',(-1.83,y,z+.53),(.10,.10,1.06),M['cream'],'02_Stairs_Detail',.008)
        lathe('Newel_WoodCap',(-1.83,y,z+1.03),[(0,.057),(.045,.064),(.08,.015)],M['wood'])
    beam('Walnut_Handrail',(-1.83,-2.66,.98),(-1.83,1.64,3.745),.045,M['wood'])
    beam('White_LowerRail',(-1.83,-2.64,.09),(-1.83,1.65,2.85),.05,M['cream'])
    beam('Landing_Handrail',(-1.83,1.60,3.745),(-1.83,2.39,3.745),.045,M['wood'])
    for i in range(1,6):lathe('Landing_Spindle_%02d'%i,(-1.83,1.60+i*.13,2.73),profile,M['cream'])
    # Solid handrail collision barrier follows the stair slope; cannot fall into room.
    rail=box('Stair_RailBarrier-colonly',(-1.81,-.50,1.90),(.12,5.02,1.08),group='90_Static_Collision')
    rail.rotation_euler.x=math.atan2(2.7,4.2);rail.hide_render=True;rail.display_type='WIRE';rail.hide_set(True)
    box('Landing_RailBarrier-colonly',(-1.81,2.0,3.25),(.12,.84,1.10),group='90_Static_Collision').hide_render=True
    # White mouldings frame the domestic scale without joining into furniture.
    for name,loc,size in [('Front',(0,-4.17,.095),(6.38,.06,.19)),('East',(3.17,0,.095),(.06,8.4,.19)),('Rear',(0,4.17,.095),(6.38,.06,.19)),('West',(-3.17,-.65,.095),(.06,7.1,.19)),('PartitionFront',(-.775,2.385,.095),(4.85,.055,.19)),('PartitionRear',(-.775,2.615,.095),(4.85,.055,.19))]:
        box('Skirting_'+name,loc,size,M['cream'],'04_Trim',.008)
        if name in ('Front','East'):bpy.data.objects['Skirting_'+name]['cutaway_hide']=True
    for name,yy,zz in [('Entry',1.34,2.70),('Exit',2.90,0)]:
        pivot=empty(name+'DoorPivot',(-3.20,yy,zz),'05_Dynamic_Doors')
        pivot['door_role']=name.lower();pivot['open_degrees']=90.0
        leaf=box(name+'Door_Leaf',(0,.53,1.10),(.055,1.06,2.20),M['cream'],'05_Dynamic_Doors',.008);leaf.parent=pivot
        for side in [-1,1]:
            for col in [.275,.785]:
                for z,h in [(.39,.45),(1.12,.72),(1.88,.37)]:
                    p=box(name+'_RaisedPanel',(side*.036,col,z),(.019,.37,h),M['cream'],'05_Dynamic_Doors',.016);p.parent=pivot
            knob=lathe(name+'_BrassKnob',(side*.08,.92,1.05),[(0,.024),(.03,.025),(.055,.037),(.085,.028)],M['metal'],'05_Dynamic_Doors',20)
            knob.parent=pivot;knob.rotation_euler.y=math.pi/2 if side>0 else -math.pi/2
        for y in [yy-.045,yy+1.105]:box(name+'_Jamb',(-3.16,y,zz+1.14),(.13,.09,2.28),M['cream'],'04_Trim',.01)
        box(name+'_CasingTop',(-3.16,yy+.53,zz+2.26),(.13,1.24,.09),M['cream'],'04_Trim',.008)
    # Fixtures have independent light sources; game varies these without changing video.
    for name,loc,energy,color in [('Main',(0.3,-1.50,2.50),160,(1.0,.79,.53)),('Rear',(0,3.4,2.50),75,(1,.81,.58)),('Stairs',(-2.53,1.2,4.91),90,(1,.79,.53))]:
        lathe(name+'_CeilingRose',(loc[0],loc[1],loc[2]+.15),[(0,.12),(.05,.15),(.09,.13)],M['cream'],'06_Lighting',24)
        lathe(name+'_OpalGlobe',(loc[0],loc[1],loc[2]-.02),[(0,.06),(.04,.11),(.12,.13),(.19,.10),(.23,.055)],M['bulb'],'06_Lighting',24)
        data=bpy.data.lights.new(name+'_PointLight','POINT');data.energy=energy;data.color=color;data.shadow_soft_size=.20
        ob=bpy.data.objects.new(name+'_PointLight',data);collection('06_Lighting').objects.link(ob);ob.location=(loc[0],loc[1],loc[2]-.08)
    # Broad soft bounce is Blender preview only; dynamic point lights are the game source.
    for name,loc,target,energy,size in [('PreviewFill',(0,-1,2.48),(0,-1,0),65,4),('RearBounce',(0,3.35,2.48),(0,3.35,0),24,2)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size;data.color=(1,.82,.63)
        ob=bpy.data.objects.new(name,data);collection('71_Preview_Only').objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector(target)-ob.location).to_track_quat('-Z','Y').to_euler()
    viewport('cutaway');bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Basement_Loop_v2.blend'))
    print('STAGE 2: independent paneled doors, spindles, skirtings and dynamic fixtures. Objects',len(scene.objects))

if __name__=='__main__':
    print('Import this file and call stage_shell(), then stage_details() separately in live Blender.')
