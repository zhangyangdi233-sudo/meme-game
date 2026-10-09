import bpy, json, math
from pathlib import Path

def export_all():
    bl=bpy.app.driver_namespace['aphasia_basement_builder'];s=bl.scene
    bpy.context.window.scene=s
    # Godot recognizes the terminal suffix; Blender's automatic .001 must precede it.
    for ob in s.objects:
        if '-colonly' in ob.name and not ob.name.endswith('-colonly'):
            base,suffix=ob.name.split('-colonly',1)
            target=base+suffix.replace('.','_')+'-colonly'
            if base=='Stair_WalkRamp':
                target='Stair_WalkRamp-colonly'
                occupied=bpy.data.objects.get(target)
                if occupied and occupied!=ob:occupied.name='Reference_'+occupied.name
            ob.name=target
    for ob in s.objects:ob.hide_set(False);ob.select_set(False)
    def choose(architecture=False):
        for ob in s.objects:
            groups={c.name for c in ob.users_collection}
            preview=any(x.startswith(('70_','71_')) for x in groups)
            isprop=any(x.startswith('Prop_') or x.startswith('91_') for x in groups)
            ob.select_set(not preview and not ob.get('exclude_export',False) and (not architecture or not isprop))
    kwargs=dict(export_format='GLB',use_selection=True,use_active_scene=True,export_apply=True,export_extras=True,export_cameras=False,export_lights=True,export_animations=False)
    choose(False);bpy.ops.export_scene.gltf(filepath=str(bl.OUT/'Basement_Loop_v2.glb'),**kwargs)
    choose(True);bpy.ops.export_scene.gltf(filepath=str(bl.OUT/'Basement_Architecture_v2.glb'),**kwargs)
    library=bl.OUT/'asset_library';library.mkdir(exist_ok=True)
    assets=bpy.app.driver_namespace['aphasia_assets']
    old=json.loads(Path(r'D:/aphasia/outputs/blender_subliminal/asset_library/props_manifest.json').read_text(encoding='utf-8'))
    for d in old['assets']:
        c=assets[d['key']];c.asset_data.description=d['description'];c.asset_data.catalog_id=d['catalog_id']
    catalogs='# Blender Asset Catalog Definition File\nVERSION 1\n\n2510f807-ae36-518e-a113-788a01a45d46:Basement/Furniture:Furniture\n10a21341-e5f9-5dd8-a738-85f8b2421dfe:Basement/Electronics and Details:Electronics and Details\n'
    if 'white_door' in assets:catalogs+=assets['white_door'].asset_data.catalog_id+':Basement/Doors:Doors\n'
    (library/'blender_assets.cats.txt').write_text(catalogs,encoding='utf-8')
    bpy.data.libraries.write(str(library/'Basement_All_Props_v2.blend'),set(assets.values()),path_remap='RELATIVE',fake_user=True,compress=True)
    paths=bpy.context.preferences.filepaths.asset_libraries
    if not any(Path(a.path)==library for a in paths):paths.new(name='Aphasia Basement v2',directory=str(library))
    bpy.ops.wm.save_userpref()
    bpy.context.window.scene=bpy.app.driver_namespace['aphasia_asset_scene']
    for key,col in assets.items():
        for ob in bpy.context.scene.objects:ob.hide_set(False);ob.select_set(False)
        for ob in col.all_objects:ob.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(library/(key+'.glb')),**kwargs)
    bpy.context.window.scene=s
    for ob in s.objects:ob.select_set(False)
    bl.viewport('camera')
    for ob in s.objects:
        if ob.get('exclude_export',False):ob.hide_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=str(bl.OUT/'Basement_Loop_v2.blend'))
    p=bl.OUT/'asset_contract.json';contract=json.loads(p.read_text(encoding='utf-8'));contract['status']='exported_runtime_validation_pending';p.write_text(json.dumps(contract,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Exported basement, architecture and',len(assets),'individual prop GLBs; registered Blender Asset Library.')

if __name__=='__main__':export_all()
