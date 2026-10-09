"""Three handmade wall paint marks; normal view hidden, X-ray render layer only."""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector

OUT=Path(r'D:/aphasia/outputs/blender_basement_loop_v2')

def build():
    s=bpy.data.scenes['Aphasia_Basement_Loop_v2']
    col=bpy.data.collections.get('12_XRay_Hidden_Marks')
    if not col:
        col=bpy.data.collections.new('12_XRay_Hidden_Marks');s.collection.children.link(col)
    mat=bpy.data.materials.get('APH_XRay_Handpaint_Red')
    if not mat:
        mat=bpy.data.materials.new('APH_XRay_Handpaint_Red');mat.use_nodes=True
        p=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        p.inputs['Base Color'].default_value=(.55,.012,.006,1);p.inputs['Roughness'].default_value=.94
        p.inputs['Emission Color'].default_value=(1,.022,.012,1);p.inputs['Emission Strength'].default_value=.35
        mat.diffuse_color=(.72,.025,.015,1)
    specs=[
        ('01',(-1.65,-4.184,1.25),(1,0,0),(0,1,0),'At stair foot: turn right across TV zone'),
        ('02',(3.184,.90,1.34),(0,1,0),(-1,0,0),'Right wall: continue toward rear NPC passage'),
        ('03',(-.78,4.184,1.30),(-1,0,0),(0,-1,0),'Rear wall: point left toward ground-floor exit door'),
    ]
    records=[]
    for index,(suffix,origin,along,normal,note) in enumerate(specs):
        name='XRAY_EXIT_GUIDE_'+suffix
        if bpy.data.objects.get(name):raise RuntimeError(name+' already exists; do not duplicate hidden arrows')
        root=bpy.data.objects.new(name,None);col.objects.link(root);root.location=origin
        root['xray_only']=True;root['guide_target']='basement_exit';root['guide_order']=index+1
        root['max_guide_count']=3;root['authoring_note']=note
        rng=random.Random(7300+index);u=Vector(along);v=Vector((0,0,1));n=Vector(normal)
        # Three irregular brush strokes assembled into a single mesh, not a perfect glyph.
        shaft=[(-.34,.025),(-.28,.033),(-.20,.007),(-.12,.014),(-.045,-.005),(.04,.003),(.13,-.008),(.23,.005),(.33,0)]
        head1=[(.13,.135),(.20,.094),(.27,.035),(.33,0)]
        head2=[(.33,0),(.25,-.043),(.19,-.101),(.105,-.141)]
        vertices=[];faces=[]
        for stroke in [shaft,head1,head2]:
            pts=[Vector((a,b+rng.uniform(-.006,.006))) for a,b in stroke]
            offset=len(vertices)
            for i,p in enumerate(pts):
                tangent=(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized()
                side=Vector((-tangent.y,tangent.x));width=rng.uniform(.009,.015)
                if i in (0,len(pts)-1):width*=.65
                for sign in [-1,1]:
                    q=p+side*width*sign;vertices.append(tuple(u*q.x+v*q.y+n*.001))
            for i in range(len(pts)-1):
                f=(offset+i*2,offset+i*2+1,offset+i*2+3,offset+i*2+2)
                a,b,c=[Vector(vertices[j]) for j in f[:3]]
                if (b-a).cross(c-a).dot(n)<0:f=tuple(reversed(f))
                faces.append(f)
        mesh=bpy.data.meshes.new(name+'_BrushMesh');mesh.from_pydata(vertices,[],faces);mesh.materials.append(mat);mesh.update()
        paint=bpy.data.objects.new(name+'_Paint',mesh);col.objects.link(paint);paint.parent=root
        paint['xray_only']=True;paint['guide_target']='basement_exit';paint['guide_order']=index+1
        paint.hide_render=True;paint.hide_set(True);root.hide_set(True)
        paint['normal_view_hidden']=True
        records.append({'root':root.name,'mesh':paint.name,'position_blender':list(origin),'arrow_direction_blender':list(along),'wall_inward_normal_blender':list(normal),'purpose':note})
    p=OUT/'asset_contract.json';d=json.loads(p.read_text(encoding='utf-8'))
    d['xray_exit_guides']={'count':3,'max_count':3,'property':'xray_only','normal_view_visible':False,'visibility_rule':'Existing camera X-ray hand-framed window only; not visible to normal world camera or ordinary camera. Hide on camera off, lost framing, phone UI or leaving basement.','marks':records}
    p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Basement_Loop_v2.blend'))
    print('Created exactly 3 handpainted exit arrows, hidden in normal Blender view; GLB export carries xray_only extras.')

if __name__=='__main__':build()
