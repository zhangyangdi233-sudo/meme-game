"""Commit the approved kids-chair wood to v2 mesh slots and export in live Blender.

Object material overrides looked correct in Blender, but the modifier-applied glTF
path retained the old paint. Isolate v2 data from reference objects before updating.
Preserve the user's current edit mode, selection, visibility and camera.
"""
import bpy, json, shutil
from pathlib import Path

OUT = Path(r'D:/aphasia/outputs/blender_basement_loop_v2')

def run():
    s = bpy.data.scenes['Aphasia_Basement_Loop_v2']
    assets = bpy.app.driver_namespace['aphasia_assets']
    asset_scene = bpy.app.driver_namespace['aphasia_asset_scene']
    old_scene = bpy.context.window.scene
    old_active = bpy.context.view_layer.objects.active
    old_mode = bpy.context.mode
    states = {sc.name: [(o, o.hide_get(), o.hide_viewport, o.select_get()) for o in sc.objects] for sc in [s, asset_scene]}
    backup = OUT / 'revisions' / 'before_kids_wood_export_20261007'
    backup.mkdir(parents=True, exist_ok=True)
    for rel in ['Basement_Loop_v2.glb', 'asset_library/kids_chair.glb', 'asset_library/Basement_All_Props_v2.blend']:
        source = OUT / rel
        target = backup / Path(rel).name
        if not target.exists():
            shutil.copy2(source, target)
    objects = set(s.objects)
    for col in assets.values():
        objects.update(col.all_objects)
    wood = bpy.data.materials['PBR_AgedWalnut.001']
    replacements = {}
    changed = []
    try:
        if bpy.context.mode != 'OBJECT':
            bpy.ops.object.mode_set(mode='OBJECT')
        for ob in sorted(objects, key=lambda item: item.name):
            if ob.type != 'MESH' or 'KidsChair' not in ob.name:
                continue
            indices = [i for i, mat in enumerate(ob.data.materials) if mat and mat.name.startswith('Paint_Teal')]
            if not indices:
                continue
            original = ob.data
            if original not in replacements:
                replacement = original.copy()
                replacement.name = original.name + '_NaturalWood'
                for i in indices:
                    replacement.materials[i] = wood
                replacements[original] = replacement
            ob.data = replacements[original]
            for i in indices:
                ob.material_slots[i].link = 'DATA'
            changed.append(ob.name)
        kwargs = dict(export_format='GLB', use_selection=True, use_active_scene=True, export_apply=True, export_extras=True, export_cameras=False, export_lights=True, export_animations=False)
        bpy.context.window.scene = s
        for ob in s.objects:
            ob.hide_viewport = False
            ob.hide_set(False)
            preview = any(c.name.startswith(('70_', '71_')) for c in ob.users_collection)
            ob.select_set(not preview and not ob.get('exclude_export', False))
        bpy.ops.export_scene.gltf(filepath=str(OUT / 'Basement_Loop_v2.glb'), **kwargs)
        bpy.context.window.scene = asset_scene
        for ob in asset_scene.objects:
            ob.hide_viewport = False
            ob.hide_set(False)
            ob.select_set(False)
        for ob in assets['kids_chair'].all_objects:
            ob.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(OUT / 'asset_library/kids_chair.glb'), **kwargs)
        bpy.data.libraries.write(str(OUT / 'asset_library/Basement_All_Props_v2.blend'), set(assets.values()), path_remap='RELATIVE', fake_user=True, compress=True)
    finally:
        for sc in [s, asset_scene]:
            bpy.context.window.scene = sc
            for ob, hidden, disabled, selected in states[sc.name]:
                ob.hide_viewport = False
                ob.hide_set(hidden)
                ob.select_set(selected)
                ob.hide_viewport = disabled
        bpy.context.window.scene = old_scene
        if old_active and old_active.name in bpy.context.view_layer.objects:
            bpy.context.view_layer.objects.active = old_active
            if old_mode == 'EDIT_MESH':
                bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'Basement_Loop_v2.blend'))
    print(json.dumps({'changed_objects': changed, 'isolated_meshes': len(replacements), 'restored_mode': bpy.context.mode, 'active_object': old_active.name if old_active else None}, ensure_ascii=False))

if __name__ == '__main__':
    run()
