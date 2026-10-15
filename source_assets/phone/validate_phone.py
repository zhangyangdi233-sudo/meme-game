"""Fresh-process import and visual validation for the exported GLB."""
from pathlib import Path
import bpy,json,struct
from mathutils import Vector

root=Path(r'D:\aphasia\meme-game')
out=Path(r'D:\aphasia\outputs\phone_revision_20261014')
src=root/'source_assets'/'phone'
glb=root/'assets'/'chapter1'/'phone_pickup.glb'
data=glb.read_bytes()
j=json.loads(data[20:20+struct.unpack_from('<I',data,12)[0]])
assert len(j['meshes'])==10
assert len(j['materials'])==5
assert not j.get('textures') and not j.get('animations') and not j.get('cameras')
assert 'phone_app_feed' in [n['name'] for n in j['nodes']]
assert 'phone_app_notebook' in [n['name'] for n in j['nodes']]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(glb))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
triangles=0
for obj in meshes:
    obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)
assert triangles==220
screen=bpy.data.objects.get('phone_screen')
normal=screen.matrix_world.to_3x3()@screen.data.polygons[0].normal
assert normal.z>.99
points=[obj.matrix_world@Vector(p) for obj in meshes for p in obj.bound_box]
lo=[min(p[i] for p in points) for i in range(3)]
hi=[max(p[i] for p in points) for i in range(3)]
dims=[hi[i]-lo[i] for i in range(3)]
assert abs(dims[0]-.076)<.00001 and abs(dims[1]-.155)<.00001

# Append only the studio helpers to the fresh imported asset.
with bpy.data.libraries.load(str(src/'phone_pickup.blend')) as (a,b):
    b.objects=[n for n in a.objects if n.startswith('Preview') or n=='preview_ground']
    b.worlds=['PreviewWorld']
for obj in b.objects:
    if obj:bpy.context.scene.collection.objects.link(obj)
scene=bpy.context.scene
scene.world=b.worlds[0]
scene.camera=bpy.data.objects.get('PreviewCamera')
scene.render.engine='CYCLES';scene.cycles.samples=16
scene.view_settings.view_transform='Standard'
scene.render.resolution_x=720;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(out/'phone_model_reimport.png')
bpy.ops.render.render(write_still=True)
report={'passed':True,'reimported_meshes':len(meshes),'triangles':triangles,'materials':len(j['materials']),'blender_dimensions_m':dims,'front_normal_blender':list(normal),'glb_contains_cameras':False,'glb_contains_reference_images':False,'render':scene.render.filepath}
(out/'phone_model_validation.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print(json.dumps(report))
