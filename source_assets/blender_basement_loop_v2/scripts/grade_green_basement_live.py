"""Live Blender art direction revision; preserve all geometry and gameplay anchors."""
import bpy, json, math, importlib.util
from pathlib import Path
from mathutils import Vector

OUT = Path(r'D:/aphasia/outputs/blender_basement_loop_v2')
TEX = OUT / 'textures_green'; TEX.mkdir(exist_ok=True)
GREEN = '#1FAE38'

def linear(hexcolor):
    values = [int(hexcolor.lstrip('#')[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(c/12.92 if c <= .04045 else ((c+.055)/1.055)**2.4 for c in values)

def init():
    spec=importlib.util.spec_from_file_location('aphasia_basement_builder',OUT/'scripts'/'build_basement_live.py')
    bl=importlib.util.module_from_spec(spec);spec.loader.exec_module(bl)
    bl.scene=bpy.data.scenes['Aphasia_Basement_Loop_v2']
    bl.COL={c.name:c for c in bpy.data.collections}
    bpy.app.driver_namespace['aphasia_basement_builder']=bl
    lib=bpy.data.scenes['Basement_Asset_Library_v2']
    names={'crt':'APH2_Asset_CRT_TV','switch':'APH2_Asset_Wall_Switch','box':'APH2_Asset_Cardboard_Box','frame':'APH2_Asset_Framed_Picture','vhs':'APH2_Asset_VHS_Stack','white_door':'APH2_Asset_WhiteDoor_Interactive'}
    names.update({k:'Asset_'+k+'.001' for k in ('console','chair','side_table','kids_table','kids_chair')})
    bpy.app.driver_namespace['aphasia_assets']={k:bpy.data.collections[v] for k,v in names.items()}
    bpy.app.driver_namespace['aphasia_asset_scene']=lib
    bpy.app.driver_namespace['aphasia_opening_scene']=bpy.data.scenes['Opening_WhiteDoor_v2']
    return bl

def principled(m):
    return next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')

def plain(name,color,rough=.65):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=principled(m);p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough
    m.diffuse_color=(*color,1);return m

def bake_grade(source,name,low,high,range_max=.35,size=1024):
    """Bake a shader colour ramp, leaving original texture pixels untouched."""
    previous=bpy.context.window.scene
    s=bpy.data.scenes.new('TextureBake_'+name);s.render.engine='CYCLES';s.cycles.samples=1
    s.cycles.device='GPU';bpy.context.window.scene=s
    me=bpy.data.meshes.new('BakeQuad_'+name);me.from_pydata([(-1,-1,0),(1,-1,0),(1,1,0),(-1,1,0)],[],[(0,1,2,3)])
    uv=me.uv_layers.new()
    for i,v in enumerate([(0,0),(1,0),(1,1),(0,1)]):uv.data[i].uv=v
    ob=bpy.data.objects.new('BakeQuad_'+name,me);s.collection.objects.link(ob)
    m=bpy.data.materials.new('BakeShader_'+name);m.use_nodes=True;ns=m.node_tree.nodes;ls=m.node_tree.links
    out=next(n for n in ns if n.type=='OUTPUT_MATERIAL')
    tex=ns.new('ShaderNodeTexImage');tex.image=source
    grey=ns.new('ShaderNodeRGBToBW');ls.new(tex.outputs['Color'],grey.inputs[0])
    ramp=ns.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=(*low,1)
    ramp.color_ramp.elements[1].position=range_max;ramp.color_ramp.elements[1].color=(*high,1)
    ls.new(grey.outputs[0],ramp.inputs[0])
    emit=ns.new('ShaderNodeEmission');ls.new(ramp.outputs['Color'],emit.inputs['Color']);ls.new(emit.outputs[0],out.inputs['Surface'])
    im=bpy.data.images.new(name,width=size,height=size,alpha=False)
    target=ns.new('ShaderNodeTexImage');target.image=im;ns.active=target;target.select=True
    me.materials.append(m);ob.select_set(True);bpy.context.view_layer.objects.active=ob
    try:
        bpy.ops.object.bake(type='EMIT',margin=2)
        im.filepath_raw=str(TEX/(name+'.png'));im.file_format='PNG';im.save();im.pack()
    finally:bpy.context.window.scene=previous
    return im

def wallpaper(low='#466E50', high='#67916B'):
    # Native procedural paper: fine woven relief, slightly embossed repeating ribs,
    # and understated paper seams. One ochre hue, no additional decorative palette.
    m=plain('APH3_Green_WovenWallpaper',linear(high),.92)
    ns=m.node_tree.nodes;ls=m.node_tree.links;p=principled(m)
    uv=ns.new('ShaderNodeTexCoord')
    noise=ns.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=6;noise.inputs['Detail'].default_value=4;noise.inputs['Roughness'].default_value=.72
    ls.new(uv.outputs['UV'],noise.inputs['Vector'])
    ramp=ns.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.15;ramp.color_ramp.elements[0].color=(*linear(low),1)
    ramp.color_ramp.elements[1].position=.85;ramp.color_ramp.elements[1].color=(*linear(high),1)
    ls.new(noise.outputs['Fac'],ramp.inputs[0])
    xy=ns.new('ShaderNodeSeparateXYZ');ls.new(uv.outputs['UV'],xy.inputs[0])
    def mathnode(op,a,b=None):
        n=ns.new('ShaderNodeMath');n.operation=op
        if hasattr(a,'node'):ls.new(a,n.inputs[0])
        else:n.inputs[0].default_value=a
        if b is not None:
            if hasattr(b,'node'):ls.new(b,n.inputs[1])
            else:n.inputs[1].default_value=b
        return n.outputs[0]
    u=mathnode('SINE',mathnode('MULTIPLY',xy.outputs['X'],math.pi*24))
    v=mathnode('SINE',mathnode('MULTIPLY',xy.outputs['Y'],math.pi*24))
    motif=mathnode('ABSOLUTE',mathnode('ADD',u,v))
    edge=mathnode('LESS_THAN',motif,.14)
    paper_pattern=mathnode('SUBTRACT',1,mathnode('MULTIPLY',edge,.065))
    seam=mathnode('GREATER_THAN',mathnode('PINGPONG',mathnode('MULTIPLY',xy.outputs['X'],4),1),.992)
    shade=mathnode('MULTIPLY',paper_pattern,mathnode('SUBTRACT',1,mathnode('MULTIPLY',seam,.2)))
    pattern_mix=ns.new('ShaderNodeMixRGB');pattern_mix.blend_type='MULTIPLY';pattern_mix.inputs[0].default_value=1
    ls.new(ramp.outputs['Color'],pattern_mix.inputs[1]);ls.new(shade,pattern_mix.inputs[2]);ls.new(pattern_mix.outputs[0],p.inputs['Base Color'])
    weave=ns.new('ShaderNodeTexWave');weave.wave_type='BANDS';weave.bands_direction='X';weave.inputs['Scale'].default_value=85;weave.inputs['Distortion'].default_value=2.5;weave.inputs['Detail Scale'].default_value=8
    ls.new(uv.outputs['UV'],weave.inputs['Vector'])
    fine=ns.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=450;fine.inputs['Detail'].default_value=2
    ls.new(uv.outputs['UV'],fine.inputs['Vector'])
    mix=ns.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=.6
    ls.new(weave.outputs['Color'],mix.inputs[1]);ls.new(fine.outputs['Fac'],mix.inputs[2])
    bump=ns.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.48;bump.inputs['Distance'].default_value=.007
    ls.new(mix.outputs[0],bump.inputs['Height']);ls.new(bump.outputs['Normal'],p.inputs['Normal'])
    return m

def bake_wallpaper(m):
    previous=bpy.context.window.scene
    s=bpy.data.scenes.new('Wallpaper_Bake');s.render.engine='CYCLES';s.cycles.samples=1;s.cycles.device='GPU';bpy.context.window.scene=s
    me=bpy.data.meshes.new('WallpaperBakeQuad');me.from_pydata([(-1,-1,0),(1,-1,0),(1,1,0),(-1,1,0)],[],[(0,1,2,3)])
    uv=me.uv_layers.new()
    for i,v in enumerate([(0,0),(1,0),(1,1),(0,1)]):uv.data[i].uv=v
    ob=bpy.data.objects.new('WallpaperBakeQuad',me);s.collection.objects.link(ob);me.materials.append(m);ob.select_set(True);bpy.context.view_layer.objects.active=ob
    ns=m.node_tree.nodes;ls=m.node_tree.links;p=principled(m);out=next(n for n in ns if n.type=='OUTPUT_MATERIAL')
    base_socket=p.inputs['Base Color'].links[0].from_socket
    emit=ns.new('ShaderNodeEmission');ls.new(base_socket,emit.inputs['Color'])
    target=ns.new('ShaderNodeTexImage');ns.active=target
    result={}
    try:
        for kind in ['base','normal']:
            im=bpy.data.images.new('APH3_Wallpaper_'+kind,1024,1024,alpha=False)
            if kind=='normal':im.colorspace_settings.name='Non-Color'
            target.image=im
            if kind=='base':ls.new(emit.outputs[0],out.inputs['Surface']);bpy.ops.object.bake(type='EMIT',margin=2)
            else:ls.new(p.outputs[0],out.inputs['Surface']);bpy.ops.object.bake(type='NORMAL',margin=2)
            im.filepath_raw=str(TEX/('wallpaper_'+kind+'.png'));im.file_format='PNG';im.save();im.pack();result[kind]=im
    finally:bpy.context.window.scene=previous
    ls.new(p.outputs[0],out.inputs['Surface'])
    t=ns.new('ShaderNodeTexImage');t.image=result['base'];ls.new(t.outputs['Color'],p.inputs['Base Color'])
    n=ns.new('ShaderNodeTexImage');n.image=result['normal'];normal=ns.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.65
    ls.new(n.outputs['Color'],normal.inputs['Color']);ls.new(normal.outputs['Normal'],p.inputs['Normal'])
    return m

def abandoned_green_furniture_study():
    bl=init();s=bl.scene;bpy.context.window.scene=s;assets=bpy.app.driver_namespace['aphasia_assets']
    g=linear(GREEN)
    wood_image=bake_grade(bpy.data.images['walnut_base.png.001'],'APH3_Green_StainedWood',tuple(v*.24 for v in g),tuple(v*1.65 for v in g),.23)
    wood=bpy.data.materials['PBR_AgedWalnut.001'].copy();wood.name='APH3_GreenWood_Grain'
    for node in wood.node_tree.nodes:
        if node.type=='TEX_IMAGE' and node.image and 'base' in node.image.name:node.image=wood_image
    wood.diffuse_color=(*g,1)
    shadow=plain('APH3_GreenWood_Shadow',tuple(v*.28 for v in g),.68)
    art_image=bake_grade(bpy.data.images['framed_art.png'],'APH3_Green_Artwork',tuple(v*.32 for v in g),tuple(v*1.8 for v in g),.5)
    art=bpy.data.materials['APH2_Framed_Art'].copy();art.name='APH3_Green_Artwork'
    next(n for n in art.node_tree.nodes if n.type=='TEX_IMAGE').image=art_image
    wall=bake_wallpaper(wallpaper())
    carpet=bpy.data.materials['PBR_TaupeLoopCarpet'].copy();carpet.name='APH3_Ochre_LoopCarpet'
    base=next(n for n in carpet.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and 'base' in n.image.name)
    base.image=bake_grade(base.image,'APH3_Ochre_Carpet',linear('#66592D'),linear('#9F8A46'),.42)
    ceiling=bpy.data.materials['PBR_PopcornCeiling'].copy();ceiling.name='APH3_Ochre_Ceiling'
    base=next(n for n in ceiling.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and 'base' in n.image.name)
    base.image=bake_grade(base.image,'APH3_Ochre_Ceiling',linear('#8F8048'),linear('#BAA45C'),.8)
    white=plain('APH3_White_Enamel',linear('#F5F5F5'),.36)
    bulb=plain('APH3_Dim_Opal_Glass',linear('#CCC5A8'),.62)
    bp=principled(bulb);bp.inputs['Emission Color'].default_value=(*linear('#DBD6BE'),1);bp.inputs['Emission Strength'].default_value=.25
    objset=set(s.objects)
    for c in assets.values():objset.update(c.all_objects)
    changed=0
    for ob in objset:
        for slot in ob.material_slots:
            old=slot.material
            if not old:continue
            name=old.name;new=None
            if name.startswith('PBR_WarmAgedPlaster'):new=wall
            elif name.startswith('PBR_TaupeLoopCarpet') and ob in s.objects.values():new=carpet
            elif name.startswith('PBR_PopcornCeiling'):new=ceiling
            elif name.startswith('PBR_AgedWalnut') or name in ('APH2_Frame_Walnut','Paint_Teal.001'):new=wood
            elif name.startswith('Walnut_Shadow'):new=shadow
            elif name=='APH2_Framed_Art':new=art
            elif name=='Glass_OpalBulb' and ob in s.objects.values():new=bulb
            if ob.name.startswith(('Walnut_Handrail','Landing_Handrail','Newel_','White_Spindle','White_LowerRail','Landing_Spindle')):new=white
            if new:slot.link='OBJECT';slot.material=new;changed+=1
    for name in ['Stairs_CeilingRose','Stairs_OpalGlobe','Stairs_PointLight']:
        ob=s.objects.get(name)
        if ob:ob['exclude_export']=True;ob['removed_by_art_direction']='No light above upstairs entrance';ob.hide_render=True;ob.hide_set(True)
    for name,energy in [('Main_PointLight',48),('Rear_PointLight',18),('Stairs_PointLight',0),('PreviewFill',5),('RearBounce',2)]:
        ob=s.objects.get(name)
        if ob:ob.data.energy=energy;ob.data.color=(1,.96,.85)
    bg=next(n for n in s.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(.08,.075,.05,1);bg.inputs[1].default_value=.025
    s.view_settings.exposure=-.4
    for c in assets.values():
        if c.asset_data:c.asset_data.tags.new('Aphasia Green Palette')
    bpy.context.window.scene=s;bl.viewport('camera')
    s.camera=s.objects['View_CRT_FromStairs']
    for ob in s.objects:
        if ob.get('exclude_export'):ob.hide_set(True)
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Basement_Loop_v2.blend'))
    print('Applied green/ochre palette to',changed,'material slots. Upstairs fixture excluded. Labels/UV/collision unchanged.')

def apply_reference():
    """Approved replacement: green room/TV light, original wood furniture and rails."""
    bl=init();s=bl.scene;bpy.context.window.scene=s;assets=bpy.app.driver_namespace['aphasia_assets']
    objects=set(s.objects)
    for col in assets.values():objects.update(col.all_objects)
    wood_meshes={}
    for ob in objects:
        for slot in ob.material_slots:
            if slot.material and slot.material.name.startswith(('APH3_GreenWood','APH3_Green_Artwork','APH3_White_Enamel')):slot.link='DATA'
            if slot.material and slot.material.name.startswith('Paint_Teal'):
                slot.link='OBJECT';slot.material=bpy.data.materials['PBR_AgedWalnut.001']
        # glTF with applied modifiers can retain mesh DATA paint instead of the
        # object's wood override. Isolate v2 meshes from reference-scene users.
        if ob.type=='MESH' and 'KidsChair' in ob.name:
            indices=[i for i,mat in enumerate(ob.data.materials) if mat and mat.name.startswith('Paint_Teal')]
            if indices:
                original=ob.data
                if original not in wood_meshes:
                    replacement=original.copy();replacement.name=original.name+'_NaturalWood'
                    for i in indices:replacement.materials[i]=bpy.data.materials['PBR_AgedWalnut.001']
                    wood_meshes[original]=replacement
                ob.data=wood_meshes[original]
                for i in indices:ob.material_slots[i].link='DATA'
    wall=bake_wallpaper(wallpaper())
    carpet=bpy.data.materials['PBR_TaupeLoopCarpet'].copy();carpet.name='APH3_Moss_LoopCarpet'
    base=next(n for n in carpet.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and 'base' in n.image.name)
    base.image=bake_grade(base.image,'APH3_Moss_Carpet',linear('#304A3A'),linear('#6D8E74'),.42)
    for ob in s.objects:
        for slot in ob.material_slots:
            if not slot.material:continue
            name=slot.material.name
            if name.startswith(('PBR_WarmAgedPlaster','APH3_Ochre_WovenWallpaper','APH3_Green_WovenWallpaper')):slot.link='OBJECT';slot.material=wall
            elif name.startswith(('PBR_TaupeLoopCarpet','APH3_Ochre_LoopCarpet','APH3_Moss_LoopCarpet')):slot.link='OBJECT';slot.material=carpet
            elif name.startswith('APH3_Ochre_Ceiling'):slot.link='DATA'
    for name in ['Stairs_CeilingRose','Stairs_OpalGlobe','Stairs_PointLight']:
        ob=s.objects.get(name)
        if ob:ob['exclude_export']=True;ob.hide_render=True;ob.hide_set(True)
    for name,energy in [('Main_PointLight',70),('Rear_PointLight',25),('Stairs_PointLight',0),('PreviewFill',14),('RearBounce',5)]:
        ob=s.objects.get(name)
        if ob:ob.data.energy=energy;ob.data.color=linear('#D4F0D1')
    bulb=bpy.data.materials['APH3_Dim_Opal_Glass'];bp=principled(bulb)
    bp.inputs['Base Color'].default_value=(*linear('#D4F0D1'),1)
    bp.inputs['Emission Color'].default_value=(*linear('#D4F0D1'),1);bp.inputs['Emission Strength'].default_value=.28
    standby=plain('APH3_CRT_Green_Standby',linear('#08270D'),.28)
    sp=principled(standby);sp.inputs['Emission Color'].default_value=(*linear('#4CFF66'),1);sp.inputs['Emission Strength'].default_value=2.2
    for ob in objects:
        if 'Screen_Video' in ob.name:
            for slot in ob.material_slots:slot.link='OBJECT';slot.material=standby
    screen=next(ob for ob in s.objects if 'Screen_Video' in ob.name)
    center=sum((screen.matrix_world@Vector(c) for c in screen.bound_box),Vector())/8
    forward=(screen.matrix_world.to_3x3()@Vector((0,-1,0))).normalized()
    for name,typ,energy,group in [('CRT_Green_AreaFill','AREA',30,'71_Preview_Only'),('CRT_Green_PointLight','POINT',5,'06_Lighting')]:
        ob=s.objects.get(name)
        if not ob:
            data=bpy.data.lights.new(name,typ);ob=bpy.data.objects.new(name,data);bl.collection(group).objects.link(ob)
        ob.location=center+forward*.15;ob.rotation_euler=forward.to_track_quat('-Z','Y').to_euler();ob.data.color=linear('#57FF73');ob.data.energy=energy
        if typ=='AREA':ob.data.shape='RECTANGLE';ob.data.size=.46;ob.data.size_y=.35
        else:ob.data.shadow_soft_size=.2
    bg=next(n for n in s.world.node_tree.nodes if n.type=='BACKGROUND');bg.inputs[0].default_value=(*linear('#3D6348'),1);bg.inputs[1].default_value=.025
    s.view_settings.exposure=0
    for col in assets.values():
        if col.asset_data:
            for tag in list(col.asset_data.tags):
                if tag.name=='Aphasia Green Palette':col.asset_data.tags.remove(tag)
    bl.viewport('camera');s.camera=s.objects['View_CRT_FromStairs']
    for ob in s.objects:
        if ob.get('exclude_export'):ob.hide_set(True)
    bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Basement_Loop_v2.blend'))
    print('Reference revision applied: green wallpaper/light/screen, original wood and art. CRT center',list(center),'forward',list(forward))

if __name__=='__main__':apply_reference()
