import bpy,uuid
from mathutils import Matrix,Vector

def add():
    bl=bpy.app.driver_namespace['aphasia_basement_builder'];s=bpy.app.driver_namespace['aphasia_opening_scene'];lib=bpy.app.driver_namespace['aphasia_asset_scene'];assets=bpy.app.driver_namespace['aphasia_assets']
    bpy.context.window.scene=s;bpy.context.view_layer.update()
    col=bpy.data.collections.new('APH2_Asset_WhiteDoor_Interactive');lib.collection.children.link(col)
    root=bpy.data.objects.new('APH2_WhiteDoor_Root',None);col.objects.link(root)
    root['asset_key']='white_door';root['origin_convention']='Frame bottom centre';root['front_direction']='-Y'
    pivot=s.objects['OpeningDoorPivot']
    chosen=[o for o in s.objects if o==pivot or o.parent==pivot or o.name.startswith(('Frame_','LightSeam_','DoorFrame_')) or o.name=='OpeningDoor_LightPlane']
    mapping={}
    for ob in chosen:
        cp=ob.copy();cp.name='AssetWhite_'+ob.name
        if '-colonly' in cp.name:
            cp.name=cp.name.replace('-colonly','').replace('.','_')+'-colonly'
        col.objects.link(cp);mapping[ob]=cp
    offset=Matrix.Translation((0,-18,0))
    for ob,cp in mapping.items():
        if ob.parent in mapping:cp.parent=mapping[ob.parent]
        else:cp.parent=root;cp.matrix_world=offset@ob.matrix_world
    col.asset_mark();col.asset_data.description='White paneled glowing door, frame and articulated hinge. Original geometry; frame floor origin; front -Y; 1.4 x .3 x 2.42m. Includes separate portal glow plane and static frame proxies.'
    col.asset_data.author='Aphasia';col.asset_data.catalog_id=str(uuid.uuid5(uuid.NAMESPACE_URL,'aphasia/basement/doors'))
    col['root_object']=root.name;col['nominal_dimensions_m']=[1.4,.3,2.42]
    col.asset_generate_preview();assets['white_door']=col
    catalog=bl.OUT/'asset_library'/'blender_assets.cats.txt'
    text=catalog.read_text(encoding='utf-8');catalog.write_text(text+col.asset_data.catalog_id+':Basement/Doors:Doors\n',encoding='utf-8')
    bpy.context.window.scene=bl.scene
    print('Added reusable door asset with articulated hinge',len(col.objects),'objects. Total',len(assets))

if __name__=='__main__':add()
