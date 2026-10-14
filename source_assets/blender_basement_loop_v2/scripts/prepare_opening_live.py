import bpy,json

def prepare():
    bl=bpy.app.driver_namespace['aphasia_basement_builder']
    s=bpy.app.driver_namespace['aphasia_opening_scene'];s.name='Opening_WhiteDoor_v2'
    bpy.context.window.scene=s
    pivot=bpy.data.objects.new('OpeningDoorPivot',None);s.collection.objects.link(pivot);pivot.location=(-.56,18,0)
    pivot['open_blender_z_degrees']=90.;pivot['unlock_rule']='narration_completed'
    bpy.context.view_layer.update()
    movable=[o for o in s.objects if o.name.startswith(('Door_Leaf','Panel_','Handle_'))]
    for ob in movable:
        mw=ob.matrix_world.copy();ob.parent=pivot;ob.matrix_world=mw
        if ob.name.startswith('Door_Leaf'):ob.name='OpeningDoor_Leaf'
    for ob in s.objects:
        if ob.name.startswith('PlayerSpawn'):
            ob.name='OpeningSpawn';ob.location=(0,0,.04);ob['position_is_feet']=True
    # A separate light surface remains in the doorway after the physical leaf swings away.
    vs=[(-.55,18.07,.01),(.55,18.07,.01),(.55,18.07,2.24),(-.55,18.07,2.24)]
    me=bpy.data.meshes.new('Opening_LightPlane');me.from_pydata(vs,[],[(0,1,2,3)]);me.update()
    mat=bpy.data.materials.new('Opening_Portal_White');mat.use_nodes=True
    bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Base Color'].default_value=(1,1,1,1);bs.inputs['Emission Color'].default_value=(1,1,1,1);bs.inputs['Emission Strength'].default_value=3
    ob=bpy.data.objects.new('OpeningDoor_LightPlane',me);s.collection.objects.link(ob);me.materials.append(mat)
    for ob in s.objects:ob.hide_set(False);ob.select_set(ob.type!='CAMERA')
    bpy.ops.export_scene.gltf(filepath=str(bl.OUT/'Opening_WhiteDoor_v2.glb'),export_format='GLB',use_active_scene=True,use_selection=True,export_apply=True,export_lights=True,export_cameras=False,export_extras=True,export_animations=False)
    for area in bpy.context.screen.areas:
        if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.overlay.show_overlays=False
    bpy.ops.wm.save_as_mainfile(filepath=str(bl.OUT/'Opening_WhiteDoor_v2.blend'))
    p=bl.OUT/'asset_contract.json';d=json.loads(p.read_text(encoding='utf-8'));d['stairs']['landing_y_max']=2.42
    d['opening'].update({'model':'Opening_WhiteDoor_v2.glb','source':'Opening_WhiteDoor_v2.blend','pivot_node':'OpeningDoorPivot','leaf_node':'OpeningDoor_Leaf','hinge_blender':[-.56,18,0],'leaf_local_center':[.56,0,1.125],'leaf_size_blender':[1.12,.08,2.25],'open_blender_z_degrees':90,'spawn_node':'OpeningSpawn','spawn_feet_blender':[0,0,.04],'forward_blender':[0,1,0],'light_plane_node':'OpeningDoor_LightPlane','moving_leaf':'All panels and handle parented to OpeningDoorPivot; frame and light seams remain fixed. Add dynamic leaf collision in Godot.'})
    p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
    bpy.context.window.scene=bl.scene;bl.viewport('camera');bpy.ops.wm.save_as_mainfile(filepath=str(bl.OUT/'Basement_Loop_v2.blend'))
    print('Opening v2: 18m door, independent hinge with',len(movable),'moving pieces; plane stays in opening. Basement file restored as active.')

if __name__=='__main__':prepare()
