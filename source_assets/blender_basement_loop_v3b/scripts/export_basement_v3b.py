"""Trial GLB export of the v3 basement (outputs only; the repo is untouched).

blender.exe --background Basement_Loop_v3.blend --python export_basement_v3.py -- --out <dir>
"""
import bpy, os, sys, json

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = ARGS[ARGS.index('--out') + 1] if '--out' in ARGS else 'D:/aphasia/outputs/basement_v3b_20261027/export'
os.makedirs(OUT, exist_ok=True)
scene = bpy.data.scenes['Aphasia_Basement_Loop_v2']
print('[export] context scene =', bpy.context.scene.name)


def exportable(ob, architecture=False):
    groups = {c.name for c in ob.users_collection}
    if any(g.startswith(('70_', '71_', '72_', '73_')) for g in groups):
        return False
    if ob.get('exclude_export', False):
        return False
    if ob.type in ('CAMERA',):
        return False
    isprop = any(g.startswith('Prop_') or g.startswith('91_') for g in groups)
    if architecture and isprop:
        return False
    return True


def run_export(path, architecture):
    with bpy.context.temp_override(scene=scene):
        vl = scene.view_layers[0]
        for ob in scene.objects:
            try:
                ob.hide_set(False, view_layer=vl)
            except Exception:
                pass
            ob.select_set(False, view_layer=vl)
        chosen = [ob for ob in scene.objects if exportable(ob, architecture)]
        for ob in chosen:
            ob.select_set(True, view_layer=vl)
        kwargs = dict(export_format='GLB', use_selection=True, use_active_scene=True, export_apply=True,
                      export_extras=True, export_cameras=False, export_lights=True, export_animations=False)
        bpy.ops.export_scene.gltf(filepath=path, **kwargs)
    print('[export] wrote', path, os.path.getsize(path), 'bytes; objects selected:', len(chosen))
    return [ob.name for ob in chosen]


names_full = run_export(os.path.join(OUT, 'Basement_Loop_v3b.glb'), False)
names_arch = run_export(os.path.join(OUT, 'Basement_Architecture_v3b.glb'), True)
with open(os.path.join(OUT, 'export_selection.json'), 'w', encoding='utf-8') as f:
    json.dump({'full': names_full, 'architecture': names_arch}, f, ensure_ascii=False, indent=1)
print('[export] done')
