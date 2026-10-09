import bpy, math
from pathlib import Path

def dress():
    bl=bpy.app.driver_namespace['aphasia_basement_builder']
    lib=bpy.data.scenes.new('Basement_Asset_Library_v2')
    p=bl.OUT/'scripts'/'build_crt_assets.py'
    ns={'__name__':'aphasia_props'};exec(compile(p.read_text(encoding='utf-8'),str(p),'exec'),ns)
    assets=ns['build_assets'](scene=lib)
    with bpy.data.libraries.load(r'D:/aphasia/outputs/blender_subliminal/asset_library/Basement_Props.blend',link=False) as (src,dst):
        dst.collections=[n for n in src.collections if n.startswith('Asset_')]
    for c in dst.collections:
        lib.collection.children.link(c)
        assets[c.name.replace('Asset_','').split('.')[0]]=c
        if not c.asset_data:c.asset_mark()
    # Real copied assemblies preserve independent editable objects and export to glTF.
    # Source asset collections remain at the origin in their own library scene.
    def assembly(key,name,loc,angle=0,scale=1):
        src=assets[key]
        col=bpy.data.collections.new(name);bl.collection('10_Separate_Props').children.link(col)
        wrapper=bpy.data.objects.new(name,None);col.objects.link(wrapper);wrapper.location=loc;wrapper.rotation_euler.z=angle;wrapper.scale=(scale,)*3
        mapping={}
        for ob in src.all_objects:
            cp=ob.copy();cp.name=name+'_'+ob.name;col.objects.link(cp);mapping[ob]=cp
        for ob,cp in mapping.items():
            if ob.parent in mapping:cp.parent=mapping[ob.parent]
            else:cp.parent=wrapper
        wrapper['source_asset_collection']=src.name
        return wrapper
    # Cabinet in the front-right TV zone, clear of the descending-stair U turn.
    console=assembly('console','Prop_MediaConsole',(1.72,-3.70,0),math.pi)
    console.scale.y=1.72
    assembly('crt','Prop_CRT_TV',(2.00,-3.69,.785),math.pi+.65)
    assembly('vhs','Prop_VHS_Console',(1.05,-3.69,.785),math.pi+.10)
    assembly('chair','Prop_Windsor_A',(-.85,1.96,0),-.10)
    assembly('chair','Prop_Windsor_B',(.03,1.96,0),.13)
    assembly('side_table','Prop_RearSideTable',(-1.64,3.90,0),0)
    assembly('kids_table','Prop_ChildTable',(-.78,-.10,0),math.pi/2)
    assembly('kids_chair','Prop_TealChair',(-.73,.61,0),.13)
    assembly('box','Prop_Box_UnderStairs',(-2.48,.84,.02),.23)
    assembly('box','Prop_Box_Rear',(1.04,3.85,.01),-.07)
    assembly('frame','Prop_Frame_Partition',(-.35,2.383,1.33),0,1.5)
    assembly('frame','Prop_Frame_Rear',(-1.51,4.16,1.39),0,1.25)
    assembly('switch','Prop_LightSwitch',(-3.171,-3.16,1.13),math.pi/2)
    # Independent simple collision boxes; props can be removed as complete collections.
    specs=[('MediaConsole',(1.72,-3.70,.39),(1.95,.86,.78)),('WindsorA',(-.85,1.96,.54),(.48,.50,1.08)),('WindsorB',(.03,1.96,.54),(.48,.50,1.08)),('RearSideTable',(-1.64,3.90,.37),(.65,.40,.74)),('ChildTable',(-.78,-.10,.285),(.62,1.05,.57)),('TealChair',(-.73,.61,.34),(.36,.38,.68))]
    for name,loc,size in specs:
        ob=bl.box('PropCollision_'+name+'-colonly',loc,size,group='91_Prop_Collision');ob.hide_render=True;ob.display_type='WIRE';ob.hide_set(True)
    bpy.app.driver_namespace['aphasia_assets']=assets
    bpy.app.driver_namespace['aphasia_asset_scene']=lib
    bpy.ops.file.pack_all()
    bl.viewport('cutaway')
    bpy.ops.wm.save_as_mainfile(filepath=str(bl.OUT/'Basement_Loop_v2.blend'))
    print('STAGE 3: 10 asset types; CRT screen and all props independently editable. Library collections:',[c.name for c in assets.values()])

if __name__=='__main__':dress()
