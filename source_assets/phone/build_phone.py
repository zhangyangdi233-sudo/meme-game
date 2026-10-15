"""Author the Aphasia phone prop in an isolated Blender background process.

Reference research is read-only and stays outside the game project. All shipped
geometry is authored here, with no reference-game image embedded in the asset.
Blender coordinates: X width, Y height (top +Y), Z thickness (screen +Z).
glTF coordinates: X width, Z height (top -Z), Y thickness (screen +Y).
"""
import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

ROOT=Path(r'D:\aphasia\meme-game')
SRC=ROOT/'source_assets'/'phone'
OUT=Path(r'D:\aphasia\outputs\phone_revision_20261014')
SRC.mkdir(parents=True,exist_ok=True)
OUT.mkdir(parents=True,exist_ok=True)
(ROOT/'assets'/'chapter1').mkdir(parents=True,exist_ok=True)

# A fresh factory scene affects only this dedicated background Blender process.
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene
scene.unit_settings.system='METRIC'
scene.unit_settings.scale_length=1.0

brief={
  'purpose':'Table pickup, first chapter; original low-poly phone',
  'size_m':[0.075,0.155,0.010],
  'camera_distance_m':[0.4,2.0],
  'triangle_budget':900,
  'texture_budget':'No textures; five flat-color materials',
  'rigging':'None',
  'collision':'Use a host-engine box; asset contains no collision',
  'export':'GLB, meters, screen +Y, top -Z, centered pivot',
  'design':'Muted plum narrow frame; broad shallow notch; cream screen; two simple app marks; sparse fine cracks',
}
(SRC/'asset_brief.json').write_text(json.dumps(brief,indent=2),encoding='utf8')

def linear(v):
    return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4

def mat(name,hexcolor,emission=0):
    rgb=[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]
    m=bpy.data.materials.new(name)
    m.diffuse_color=(*[linear(v) for v in rgb],1)
    m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=m.diffuse_color
    p.inputs['Roughness'].default_value=.9
    p.inputs['Specular IOR Level'].default_value=.15
    if emission:
        # An unlit display keeps the project's cream constant in every room.
        nodes=m.node_tree.nodes
        nodes.remove(p)
        e=nodes.new('ShaderNodeEmission')
        e.inputs['Color'].default_value=m.diffuse_color
        e.inputs['Strength'].default_value=1.0
        m.node_tree.links.new(e.outputs[0],nodes.get('Material Output').inputs['Surface'])
    return m

casing=mat('mat_phone_plum_shell','3F2937')
edge=mat('mat_phone_soft_edge','8B7B80')
screen=mat('mat_phone_cream_screen','FFF1C9',.6)
ink=mat('mat_phone_ink','362530')
crack=mat('mat_phone_hairline_cracks','BDB6A7',.3)

def mesh(name,verts,faces,materials,face_mats=None):
    data=bpy.data.meshes.new(name+'_mesh'); data.from_pydata(verts,[],faces); data.update()
    obj=bpy.data.objects.new(name,data); scene.collection.objects.link(obj)
    for material in materials: data.materials.append(material)
    if face_mats:
        for p,i in zip(data.polygons,face_mats): p.material_index=i
    for p in data.polygons: p.use_smooth=False
    return obj

def rounded(w,h,r,steps=3):
    pts=[]
    for cx,cy,start in ((w/2-r,h/2-r,0),(-w/2+r,h/2-r,90),(-w/2+r,-h/2+r,180),(w/2-r,-h/2+r,270)):
        for k in range(steps+1):
            a=math.radians(start+k*90/steps)
            pts.append((cx+r*math.cos(a),cy+r*math.sin(a)))
    return pts

def panel(name,w,h,r,z,material,cx=0,cy=0):
    pts=rounded(w,h,r)
    return mesh(name,[(x+cx,y+cy,z) for x,y in pts],[tuple(range(len(pts)))],[material])

# Simple faceted chamfer: three silhouette rings, no subdivision or smooth normals.
ring_specs=[(.073,.153,.0055,-.005),(.075,.155,.006,.0037),(.0738,.1538,.0057,.005)]
verts=[]
for w,h,r,z in ring_specs: verts += [(x,y,z) for x,y in rounded(w,h,r)]
n=len(verts)//len(ring_specs)
faces=[tuple(reversed(range(n)))]; indices=[0]
for j in range(2):
    for i in range(n):
        k=(i+1)%n
        faces.append((j*n+i,j*n+k,(j+1)*n+k,(j+1)*n+i));indices.append(1 if j==1 else 0)
faces.append(tuple(range(2*n,3*n)));indices.append(0)
mesh('phone_shell',verts,faces,[casing,edge],indices)

# The black-purple bezel remains visible all around the almost edge-to-edge panel.
panel('phone_screen',.0685,.1465,.0038,.00503,screen)
# Wide, shallow top notch with small faceted lower corners.
notch_pts=[(-.0165,.074),(.0165,.074),(.0165,.0709),(.0158,.0698),(.0146,.0694),(-.0146,.0694),(-.0158,.0698),(-.0165,.0709)]
mesh('phone_notch',[(x,y,.00508) for x,y in reversed(notch_pts)],[tuple(range(8))],[casing])
panel('phone_earpiece',.0122,.0013,.00065,.00512,ink,cx=.0018,cy=.0718)

def disc(name,x,y,r,z,material,sides=8):
    verts=[(x+math.cos(i*math.tau/sides)*r,y+math.sin(i*math.tau/sides)*r,z) for i in range(sides)]
    return mesh(name,verts,[tuple(range(sides))],[material])
disc('phone_front_camera',-.0076,.0718,.00085,.00513,ink)

def strokes(name,paths,width,z,material):
    verts=[];faces=[]
    for path in paths:
        for p,q in zip(path,path[1:]):
            dx=q[0]-p[0];dy=q[1]-p[1];ln=math.hypot(dx,dy)
            nx=-dy/ln*width/2;ny=dx/ln*width/2
            start=len(verts)
            verts.extend([(p[0]+nx,p[1]+ny,z),(p[0]-nx,p[1]-ny,z),(q[0]-nx,q[1]-ny,z),(q[0]+nx,q[1]+ny,z)])
            faces.append(tuple(range(start,start+4)))
    return mesh(name,verts,faces,[material])

# Two icon-only marks, the left an asymmetric waterfall/feed grid, right a notebook.
left=-.0156
feed_paths=[]
for x,y,w,h in ((left-.005,.021,.0042,.007),(left+.001,.021,.0042,.004),(left-.005,.012,.0042,.004),(left+.001,.015,.0042,.007)):
    feed_paths.append([(x,y),(x+w,y),(x+w,y-h),(x,y-h),(x,y)])
strokes('phone_app_feed',feed_paths,.00058,.00515,ink)
x=.0106;y=.021
note_paths=[[(x,y),(x+.010,y),(x+.010,y-.014),(x,y-.014),(x,y)],[(x+.0025,y),(x+.0025,y-.014)],[(x+.0044,y-.004),(x+.0082,y-.004)],[(x+.0044,y-.007),(x+.0082,y-.007)],[(x+.0044,y-.010),(x+.0072,y-.010)]]
strokes('phone_app_notebook',note_paths,.00060,.00515,ink)

# Sparse, very fine fractures in the upper right. They do not form a heavy web.
crack_paths=[[(.0328,.059),(.0273,.053),(.0281,.047),(.0231,.041),(.0223,.034)],[(.0273,.053),(.0215,.0558),(.0182,.055)],[(.0281,.047),(.0329,.0444)],[(.0231,.041),(.0175,.0374)]]
strokes('phone_glass_fine_cracks',crack_paths,.00013,.00518,crack)

def box(name,loc,scale,material):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc)
    obj=bpy.context.object;obj.name=name;obj.dimensions=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(material)
    return obj
box('phone_power_button',(.0377,.029,-.0001),(.0006,.009,.002),casing)
box('phone_volume_button',(-.0377,.030,-.0001),(.0006,.016,.002),casing)

asset_objects=[o for o in scene.objects if o.type=='MESH']
triangles=0
for obj in asset_objects:
    obj.data.calc_loop_triangles();triangles+=len(obj.data.loop_triangles)

for obj in scene.objects: obj.select_set(False)
for obj in asset_objects: obj.select_set(True)
bpy.context.view_layer.objects.active=asset_objects[0]
glb=ROOT/'assets'/'chapter1'/'phone_pickup.glb'
bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
(SRC/'phone_pickup.glb').write_bytes(glb.read_bytes())

# Neutral studio scene kept in the editable blend, excluded from the GLB.
floor_mat=mat('preview_ground','B7B5AA')
box('preview_ground',(0,0,-.006),(.8,.8,.001),floor_mat)
scene.world=bpy.data.worlds.new('PreviewWorld')
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.6,.6,.6,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7

def area(name,loc,energy,size):
    bpy.ops.object.light_add(type='AREA',location=loc)
    obj=bpy.context.object;obj.name=name;obj.data.energy=energy;obj.data.shape='DISK';obj.data.size=size
    obj.rotation_euler=(Vector((0,0,0))-obj.location).to_track_quat('-Z','Y').to_euler()
area('PreviewKey',(-.18,.12,.3),.07,.25)
area('PreviewFill',(.15,-.05,.15),.03,.2)
bpy.ops.object.camera_add(location=(.105,-.13,.26))
camera=bpy.context.object;camera.name='PreviewCamera';camera.data.type='ORTHO';camera.data.ortho_scale=.205
camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler()
scene.camera=camera
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.render.resolution_x=900;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.view_settings.view_transform='Standard'
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(OUT/'phone_model_perspective.png')
scene.render.film_transparent=False
bpy.ops.render.render(write_still=True)
camera.location=(0,0,.3)
camera.rotation_euler=(0,0,0)
camera.data.ortho_scale=.18
scene.render.filepath=str(OUT/'phone_model_front.png')
bpy.ops.render.render(write_still=True)

for obj in scene.objects:obj.select_set(False)
for obj in asset_objects:obj.select_set(True)
bpy.context.view_layer.objects.active=asset_objects[0]
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'phone_pickup.blend'))
stats={'meshes':len(asset_objects),'triangles':triangles,'asset_materials':5,'textures':0,'animations':0,'rig':False,'dimensions_glb_m':[.076,.01018,.155],'origin':'body center','screen_normal_glb':[0,1,0],'phone_top_glb':[0,0,-1],'glb_bytes':glb.stat().st_size,'preview_front':str(OUT/'phone_model_front.png'),'preview_perspective':str(OUT/'phone_model_perspective.png')}
(SRC/'phone_asset_stats.json').write_text(json.dumps(stats,indent=2),encoding='utf8')
(OUT/'phone_asset_stats.json').write_text(json.dumps(stats,indent=2),encoding='utf8')
print('PHONE_ASSET_STATS',json.dumps(stats))
