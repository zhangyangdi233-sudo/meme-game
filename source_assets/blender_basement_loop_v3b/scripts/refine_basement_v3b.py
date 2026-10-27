"""Aphasia basement "质感版" (v3b): refine the EXISTING v2 model without adding props.

What it does (all switchable):
  --materials 1  bake 2K seamless detail maps (periodic 4D noise) on top of the user's own
                 APH3 green textures, build PBR materials, assign them at object level and
                 re-project world-metric UVs so tiling is correct in Godot without triplanar.
  --geometry 1   bevels + smooth shading on existing stair/trim/rail objects, close the
                 stepped stair side with a painted stringer and the nook under the landing.
  --lighting 1   dreamcore preview lighting: one dim green-warm globe, haze, AgX, low exposure.
  --render views renders the review cameras; --tag names the outputs.

blender.exe --background Basement_Loop_v2.blend --python refine_basement_v3b.py -- --out <dir> [...]
"""
import bpy, bmesh, math, json, os, sys, time
from mathutils import Vector, Matrix, Euler

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []


def arg(name, default):
    return ARGS[ARGS.index(name) + 1] if name in ARGS else default


OUT = arg('--out', 'D:/aphasia/outputs/basement_v3b_20261027')
DO_MAT = arg('--materials', '1') == '1'
DO_GEO = arg('--geometry', '1') == '1'
DO_LIGHT = arg('--lighting', '1') == '1'
DO_STRINGER = arg('--stringer', '1') == '1'
SAVE = arg('--save', '1') == '1'
RENDER = [s for s in arg('--render', 'views').split(',') if s]
SAMPLES = int(arg('--samples', '128'))
TAG = arg('--tag', 'v3b')
BAKE_SIZE = int(arg('--bake', '2048'))
VIEW_FILTER = [s for s in arg('--only', '').split(',') if s]
MAIN_W = float(arg('--main-w', '28'))
REAR_W = float(arg('--rear-w', '7'))
CRT_W = float(arg('--crt-w', '3.5'))
HAZE = float(arg('--haze', '0.010'))
EXPOSURE = float(arg('--exposure', '-0.1'))
os.makedirs(OUT, exist_ok=True)
TEXDIR = os.path.join(OUT, 'textures')
os.makedirs(TEXDIR, exist_ok=True)
LOG = []


def log(*a):
    s = ' '.join(str(x) for x in a)
    print('[v3b]', s, flush=True)
    LOG.append(s)


scene = bpy.data.scenes['Aphasia_Basement_Loop_v2']
XW, XE, YF, YR, ZC = -3.2, 3.2, -4.2, 4.2, 2.75


def leave_edit_mode():
    # The v2 file was saved with a mesh in Edit Mode; bmesh.to_mesh refuses such meshes.
    for ob in bpy.data.objects:
        if ob.type == 'MESH' and ob.mode == 'EDIT':
            try:
                vl = scene.view_layers[0]
                with bpy.context.temp_override(scene=scene, view_layer=vl, active_object=ob, object=ob,
                                               selected_objects=[ob], selected_editable_objects=[ob]):
                    bpy.ops.object.mode_set(mode='OBJECT')
                print('[v3b] left edit mode on', ob.name)
            except Exception as e:
                print('[v3b] could not leave edit mode on', ob.name, e)
                try:
                    ob.update_from_editmode()
                except Exception:
                    pass


leave_edit_mode()


def refresh():
    try:
        scene.view_layers[0].update()
    except Exception:
        pass


def effective_material(ob, index=0):
    if index >= len(ob.material_slots):
        return None
    return ob.material_slots[index].material


# ----------------------------------------------------------------------------- object sets
def names_with(prefixes=(), exact=()):
    out = []
    for ob in scene.objects:
        if ob.type != 'MESH':
            continue
        if ob.name in exact or ob.name.startswith(tuple(prefixes)):
            out.append(ob)
    return out


WALLS = names_with(prefixes=('Wall_', 'Stairwell_', 'Entry_VestibuleBack', 'Entry_VestibuleSide', 'Exit_VestibuleBack', 'Exit_VestibuleSide'),
                   exact=('NPC_Partition', 'Exit_Lintel'))
CEILINGS = names_with(prefixes=('Ceiling_',), exact=('Entry_VestibuleCeiling', 'Exit_VestibuleCeiling'))
CARPETS = names_with(prefixes=('Carpet_Tread_', 'Carpet_Riser_'), exact=('Room_Floor', 'Stair_UpperLanding', 'Entry_VestibuleFloor', 'Exit_VestibuleFloor'))
PAINTS = [ob for ob in scene.objects if ob.type == 'MESH' and effective_material(ob) is not None and effective_material(ob).name == 'Paint_OffWhite'
          and not ob.name.endswith('-colonly')]
WALLS = [o for o in WALLS if not o.name.endswith('-colonly')]
CEILINGS = [o for o in CEILINGS if not o.name.endswith('-colonly')]
CARPETS = [o for o in CARPETS if not o.name.endswith('-colonly')]
log('sets: walls=%d ceilings=%d carpets=%d paints=%d' % (len(WALLS), len(CEILINGS), len(CARPETS), len(PAINTS)))


# ----------------------------------------------------------------------------- node helpers
def principled(mat):
    return next((n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)


def new_material(name):
    m = bpy.data.materials.get(name)
    if m is not None:
        bpy.data.materials.remove(m)
    m = bpy.data.materials.new(name)
    try:
        if not m.node_tree:
            m.use_nodes = True
    except Exception:
        pass
    nt = m.node_tree
    if principled(m) is None:
        b = nt.nodes.new('ShaderNodeBsdfPrincipled')
        o = next((n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'), None) or nt.nodes.new('ShaderNodeOutputMaterial')
        nt.links.new(b.outputs['BSDF'], o.inputs['Surface'])
    return m


def find_image(*candidates):
    for c in candidates:
        img = bpy.data.images.get(c)
        if img is not None and img.size[0] > 0:
            return img
    return None


def periodic_coords(nt, uv_socket, features):
    """Map UV (0..1) onto a torus in 4D so noise sampled there tiles seamlessly.
    Returns (vector_socket, w_socket). 'features' ~ number of noise features per tile."""
    nodes, links = nt.nodes, nt.links
    R = features / (2.0 * math.pi)
    sep = nodes.new('ShaderNodeSeparateXYZ')
    links.new(uv_socket, sep.inputs[0])
    outs = []
    for axis in (0, 1):
        ang = nodes.new('ShaderNodeMath')
        ang.operation = 'MULTIPLY'
        ang.inputs[1].default_value = 2.0 * math.pi
        links.new(sep.outputs[axis], ang.inputs[0])
        for op in ('COSINE', 'SINE'):
            t = nodes.new('ShaderNodeMath')
            t.operation = op
            links.new(ang.outputs[0], t.inputs[0])
            sc = nodes.new('ShaderNodeMath')
            sc.operation = 'MULTIPLY'
            sc.inputs[1].default_value = R
            links.new(t.outputs[0], sc.inputs[0])
            outs.append(sc.outputs[0])
    comb = nodes.new('ShaderNodeCombineXYZ')
    links.new(outs[0], comb.inputs['X'])
    links.new(outs[1], comb.inputs['Y'])
    links.new(outs[2], comb.inputs['Z'])
    return comb.outputs['Vector'], outs[3]


def noise4d(nt, uv_socket, features, detail=3.0, rough=0.5, distortion=0.0):
    vec, w = periodic_coords(nt, uv_socket, features)
    n = nt.nodes.new('ShaderNodeTexNoise')
    n.noise_dimensions = '4D'
    n.inputs['Scale'].default_value = 1.0
    n.inputs['Detail'].default_value = detail
    n.inputs['Roughness'].default_value = rough
    if 'Distortion' in n.inputs:
        n.inputs['Distortion'].default_value = distortion
    nt.links.new(vec, n.inputs['Vector'])
    nt.links.new(w, n.inputs['W'])
    return n.outputs['Fac']


def voronoi4d(nt, uv_socket, features, smooth=0.5, randomness=1.0, feature='SMOOTH_F1'):
    vec, w = periodic_coords(nt, uv_socket, features)
    v = nt.nodes.new('ShaderNodeTexVoronoi')
    v.voronoi_dimensions = '4D'
    v.feature = feature
    v.inputs['Scale'].default_value = 1.0
    if 'Smoothness' in v.inputs:
        v.inputs['Smoothness'].default_value = smooth
    v.inputs['Randomness'].default_value = randomness
    nt.links.new(vec, v.inputs['Vector'])
    nt.links.new(w, v.inputs['W'])
    return v.outputs['Distance']


def math_node(nt, op, a, b=None, c=None):
    n = nt.nodes.new('ShaderNodeMath')
    n.operation = op
    for i, val in enumerate((a, b, c)):
        if val is None:
            continue
        if hasattr(val, 'node'):
            nt.links.new(val, n.inputs[i])
        else:
            n.inputs[i].default_value = val
    return n.outputs[0]


def image_node(nt, img, uv_socket=None, noncolor=False):
    t = nt.nodes.new('ShaderNodeTexImage')
    t.image = img
    t.interpolation = 'Linear'
    if noncolor:
        try:
            img.colorspace_settings.name = 'Non-Color'
        except Exception:
            pass
    if uv_socket is not None:
        nt.links.new(uv_socket, t.inputs['Vector'])
    return t


# ----------------------------------------------------------------------------- baking
BAKE_SCENE = None
BAKE_PLANE = None


def bake_setup():
    global BAKE_SCENE, BAKE_PLANE
    s = bpy.data.scenes.get('V3B_Bake')
    if s is None:
        s = bpy.data.scenes.new('V3B_Bake')
    s.render.engine = 'CYCLES'
    s.cycles.samples = 24
    s.cycles.use_denoising = False
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type = 'OPTIX'
        prefs.get_devices()
        for d in prefs.devices:
            d.use = d.type != 'CPU'
        s.cycles.device = 'GPU'
    except Exception as e:
        log('bake GPU unavailable:', e)
    s.render.bake.margin = 6
    s.render.bake.use_clear = True
    s.render.bake.target = 'IMAGE_TEXTURES'
    s.render.bake.normal_space = 'TANGENT'
    s.render.bake.use_pass_direct = False
    s.render.bake.use_pass_indirect = False
    s.render.bake.use_pass_color = True
    me = bpy.data.meshes.new('V3B_BakePlane')
    me.from_pydata([(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)], [], [(0, 1, 2, 3)])
    uv = me.uv_layers.new(name='UVMap')
    for i, v in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]):
        uv.data[i].uv = v
    plane = bpy.data.objects.new('V3B_BakePlane', me)
    s.collection.objects.link(plane)
    BAKE_SCENE, BAKE_PLANE = s, plane


def bake(mat, kind, name, size, noncolor):
    """Bake one map from 'mat' (which must have a target image node made active)."""
    img = bpy.data.images.get(name)
    if img is not None:
        bpy.data.images.remove(img)
    img = bpy.data.images.new(name, width=size, height=size, alpha=False, float_buffer=False)
    if noncolor:
        img.colorspace_settings.name = 'Non-Color'
    nt = mat.node_tree
    target = nt.nodes.new('ShaderNodeTexImage')
    target.image = img
    for n in nt.nodes:
        n.select = False
    target.select = True
    nt.nodes.active = target
    me = BAKE_PLANE.data
    me.materials.clear()
    me.materials.append(mat)
    vl = BAKE_SCENE.view_layers[0]
    BAKE_PLANE.select_set(True, view_layer=vl)
    vl.objects.active = BAKE_PLANE
    t = time.time()
    with bpy.context.temp_override(scene=BAKE_SCENE, view_layer=vl, active_object=BAKE_PLANE, object=BAKE_PLANE,
                                   selected_objects=[BAKE_PLANE], selected_editable_objects=[BAKE_PLANE]):
        if kind == 'DIFFUSE':
            bpy.ops.object.bake(type='DIFFUSE', pass_filter={'COLOR'}, margin=6, use_clear=True)
        elif kind == 'NORMAL':
            bpy.ops.object.bake(type='NORMAL', margin=6, use_clear=True, normal_space='TANGENT')
        else:
            bpy.ops.object.bake(type='ROUGHNESS', margin=6, use_clear=True)
    path = os.path.join(TEXDIR, name + '.png')
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    img.pack()
    nt.nodes.remove(target)
    log('baked %s %s %dpx in %.1fs' % (kind, name, size, time.time() - t))
    return img


def build_bake_material(name, tile_m, base_image=None, base_rgb=None, base_hsv=None,
                        old_normal=None, old_normal_strength=0.0, detail=None, rough_fn=None):
    """detail: callable(nt, uv_socket) -> (height_socket, bump_strength, bump_distance)
       rough_fn: callable(nt, uv_socket) -> roughness socket"""
    m = new_material('V3B_Bake_' + name)
    nt = m.node_tree
    p = principled(m)
    tc = nt.nodes.new('ShaderNodeTexCoord')
    uv = tc.outputs['UV']
    # base colour
    if base_image is not None:
        t = image_node(nt, base_image, uv)
        col = t.outputs['Color']
        if base_hsv is not None:
            hsv = nt.nodes.new('ShaderNodeHueSaturation')
            hsv.inputs['Hue'].default_value = base_hsv[0]
            hsv.inputs['Saturation'].default_value = base_hsv[1]
            hsv.inputs['Value'].default_value = base_hsv[2]
            nt.links.new(col, hsv.inputs['Color'])
            col = hsv.outputs['Color']
        nt.links.new(col, p.inputs['Base Color'])
    elif base_rgb is not None:
        p.inputs['Base Color'].default_value = (base_rgb[0], base_rgb[1], base_rgb[2], 1.0)
    # normal chain: optional old normal map -> bump with periodic detail
    normal_socket = None
    if old_normal is not None and old_normal_strength > 0:
        t = image_node(nt, old_normal, uv, noncolor=True)
        nm = nt.nodes.new('ShaderNodeNormalMap')
        nm.space = 'TANGENT'
        nm.inputs['Strength'].default_value = old_normal_strength
        nt.links.new(t.outputs['Color'], nm.inputs['Color'])
        normal_socket = nm.outputs['Normal']
    if detail is not None:
        height, strength, distance = detail(nt, uv)
        bump = nt.nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = strength
        bump.inputs['Distance'].default_value = distance
        nt.links.new(height, bump.inputs['Height'])
        if normal_socket is not None:
            nt.links.new(normal_socket, bump.inputs['Normal'])
        normal_socket = bump.outputs['Normal']
    if normal_socket is not None:
        nt.links.new(normal_socket, p.inputs['Normal'])
    if rough_fn is not None:
        nt.links.new(rough_fn(nt, uv), p.inputs['Roughness'])
    return m


def final_material(name, base_image, normal_image, rough_image, base_rgb=None, viewport_rgb=(0.5, 0.5, 0.5)):
    m = new_material(name)
    nt = m.node_tree
    p = principled(m)
    tc = nt.nodes.new('ShaderNodeTexCoord')
    uv = tc.outputs['UV']
    if base_image is not None:
        t = image_node(nt, base_image, uv)
        nt.links.new(t.outputs['Color'], p.inputs['Base Color'])
    elif base_rgb is not None:
        p.inputs['Base Color'].default_value = (base_rgb[0], base_rgb[1], base_rgb[2], 1.0)
    if rough_image is not None:
        t = image_node(nt, rough_image, uv, noncolor=True)
        nt.links.new(t.outputs['Color'], p.inputs['Roughness'])
    if normal_image is not None:
        t = image_node(nt, normal_image, uv, noncolor=True)
        nm = nt.nodes.new('ShaderNodeNormalMap')
        nm.space = 'TANGENT'
        nm.inputs['Strength'].default_value = 1.0
        nt.links.new(t.outputs['Color'], nm.inputs['Color'])
        nt.links.new(nm.outputs['Normal'], p.inputs['Normal'])
    if 'Specular IOR Level' in p.inputs:
        p.inputs['Specular IOR Level'].default_value = 0.4
    m.diffuse_color = (viewport_rgb[0], viewport_rgb[1], viewport_rgb[2], 1.0)
    return m


def assign_object_material(ob, mat):
    if len(ob.material_slots) == 0:
        ob.data.materials.append(mat)
    for slot in ob.material_slots:
        slot.link = 'OBJECT'
        slot.material = mat


def project_uv(ob, tile, space):
    """Box-project UVs in metres / tile. space: 'world' or 'local'."""
    me = ob.data
    if me.is_editmode:
        log('skip UV (editmode):', ob.name)
        return
    bm = bmesh.new()
    bm.from_mesh(me)
    uv_layer = bm.loops.layers.uv.active or bm.loops.layers.uv.new('UVMap')
    M = ob.matrix_world if space == 'world' else Matrix.Identity(4)
    R = M.to_3x3()
    for f in bm.faces:
        n = (R @ f.normal)
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            co = M @ l.vert.co
            if ax == 0:
                uv = (co.y, co.z)
            elif ax == 1:
                uv = (co.x, co.z)
            else:
                uv = (co.x, co.y)
            l[uv_layer].uv = (uv[0] / tile, uv[1] / tile)
    bm.to_mesh(me)
    bm.free()


def uv_space_for(ob):
    if ob.parent is not None or ob.data.users > 1:
        return 'local'
    return 'world'


# ----------------------------------------------------------------------------- materials pass
def materials_pass():
    bake_setup()
    wp_base = find_image('APH3_Wallpaper_base.002', 'APH3_Wallpaper_base', 'wallpaper_base.png')
    wp_norm = find_image('APH3_Wallpaper_normal.002', 'APH3_Wallpaper_normal', 'wallpaper_normal.png')
    cp_base = find_image('APH3_Moss_Carpet', 'carpet_base.png')
    cp_norm = find_image('carpet_normal.png')
    ce_base = find_image('APH3_Ochre_Ceiling', 'ceiling_base.png')
    ce_norm = find_image('ceiling_normal.png')
    log('source images:', [i.name if i else None for i in (wp_base, wp_norm, cp_base, cp_norm, ce_base, ce_norm)])
    paint_old = bpy.data.materials.get('Paint_OffWhite')
    paint_rgb = (0.80, 0.78, 0.70)
    if paint_old is not None and principled(paint_old) is not None:
        c = principled(paint_old).inputs['Base Color'].default_value
        paint_rgb = (c[0] * 0.96, c[1] * 0.95, c[2] * 0.90)

    # --- wallpaper (tile 1.6 m): paper grain + woven relief on top of the user's trellis normal
    def wp_detail(nt, uv):
        grain = noise4d(nt, uv, 220, detail=2.0, rough=0.6)          # ~7 mm paper grain
        weave = noise4d(nt, uv, 640, detail=1.0, rough=0.4)          # ~2.5 mm fibre
        h = math_node(nt, 'ADD', math_node(nt, 'MULTIPLY', grain, 0.7), math_node(nt, 'MULTIPLY', weave, 0.3))
        return h, 0.45, 0.002

    def wp_rough(nt, uv):
        n = noise4d(nt, uv, 90, detail=2.0, rough=0.5)
        return math_node(nt, 'ADD', 0.70, math_node(nt, 'MULTIPLY', n, 0.12))

    m = build_bake_material('wallpaper', 1.6, base_image=wp_base, base_hsv=(0.5, 0.88, 0.92), old_normal=wp_norm,
                            old_normal_strength=0.75, detail=wp_detail, rough_fn=wp_rough)
    wp_b = bake(m, 'DIFFUSE', 'V3B_wallpaper_base', 1024, False) if wp_base is not None else None
    wp_n = bake(m, 'NORMAL', 'V3B_wallpaper_normal', BAKE_SIZE, True)
    wp_r = bake(m, 'ROUGH', 'V3B_wallpaper_rough', 1024, True)

    # --- carpet (tile 1.0 m): loop pile cells on top of the user's carpet normal
    def cp_detail(nt, uv):
        loops = voronoi4d(nt, uv, 260, smooth=0.35, randomness=0.9)   # ~4 mm loops
        fuzz = noise4d(nt, uv, 700, detail=1.0, rough=0.5)
        h = math_node(nt, 'ADD', math_node(nt, 'MULTIPLY', loops, 0.8), math_node(nt, 'MULTIPLY', fuzz, 0.2))
        return h, 0.6, 0.0025

    def cp_rough(nt, uv):
        n = noise4d(nt, uv, 120, detail=2.0, rough=0.5)
        return math_node(nt, 'ADD', 0.86, math_node(nt, 'MULTIPLY', n, 0.10))

    m = build_bake_material('carpet', 1.0, base_image=cp_base, base_hsv=(0.5, 0.92, 0.9), old_normal=cp_norm,
                            old_normal_strength=0.5, detail=cp_detail, rough_fn=cp_rough)
    cp_b = bake(m, 'DIFFUSE', 'V3B_carpet_base', 1024, False) if cp_base is not None else None
    cp_n = bake(m, 'NORMAL', 'V3B_carpet_normal', BAKE_SIZE, True)
    cp_r = bake(m, 'ROUGH', 'V3B_carpet_rough', 1024, True)

    # --- popcorn ceiling (tile 1.0 m): blobby acoustic texture
    def ce_detail(nt, uv):
        blobs = voronoi4d(nt, uv, 150, smooth=0.6, randomness=1.0)    # ~7 mm blobs
        fine = voronoi4d(nt, uv, 420, smooth=0.4, randomness=1.0)
        mod = noise4d(nt, uv, 40, detail=1.0, rough=0.5)
        inv = math_node(nt, 'SUBTRACT', 1.0, blobs)
        h = math_node(nt, 'ADD', math_node(nt, 'MULTIPLY', inv, 0.75), math_node(nt, 'MULTIPLY', math_node(nt, 'SUBTRACT', 1.0, fine), 0.25))
        h = math_node(nt, 'MULTIPLY', h, math_node(nt, 'ADD', 0.7, math_node(nt, 'MULTIPLY', mod, 0.6)))
        return h, 0.9, 0.004

    def ce_rough(nt, uv):
        n = noise4d(nt, uv, 150, detail=2.0, rough=0.5)
        return math_node(nt, 'ADD', 0.82, math_node(nt, 'MULTIPLY', n, 0.12))

    m = build_bake_material('ceiling', 1.0, base_image=ce_base, base_hsv=(0.5, 0.9, 0.95), old_normal=ce_norm,
                            old_normal_strength=0.4, detail=ce_detail, rough_fn=ce_rough)
    ce_b = bake(m, 'DIFFUSE', 'V3B_ceiling_base', 1024, False) if ce_base is not None else None
    ce_n = bake(m, 'NORMAL', 'V3B_ceiling_normal', BAKE_SIZE, True)
    ce_r = bake(m, 'ROUGH', 'V3B_ceiling_rough', 1024, True)

    # --- satin paint (tile 0.5 m): orange-peel micro relief, soft roughness variation
    def pt_detail(nt, uv):
        peel = noise4d(nt, uv, 170, detail=2.0, rough=0.55)           # ~3 mm orange peel
        brush = noise4d(nt, uv, 60, detail=1.5, rough=0.5)
        h = math_node(nt, 'ADD', math_node(nt, 'MULTIPLY', peel, 0.75), math_node(nt, 'MULTIPLY', brush, 0.25))
        return h, 0.18, 0.0006

    def pt_rough(nt, uv):
        n = noise4d(nt, uv, 50, detail=2.0, rough=0.5)
        return math_node(nt, 'ADD', 0.30, math_node(nt, 'MULTIPLY', n, 0.16))

    m = build_bake_material('paint', 0.5, base_rgb=paint_rgb, detail=pt_detail, rough_fn=pt_rough)
    pt_n = bake(m, 'NORMAL', 'V3B_paint_normal', 1024, True)
    pt_r = bake(m, 'ROUGH', 'V3B_paint_rough', 1024, True)

    M_WP = final_material('V3B_Wallpaper', wp_b, wp_n, wp_r, viewport_rgb=(0.3, 0.45, 0.33))
    M_CP = final_material('V3B_Carpet', cp_b, cp_n, cp_r, viewport_rgb=(0.25, 0.33, 0.24))
    M_CE = final_material('V3B_PopcornCeiling', ce_b, ce_n, ce_r, viewport_rgb=(0.7, 0.66, 0.55))
    M_PT = final_material('V3B_PaintSatin', None, pt_n, pt_r, base_rgb=paint_rgb, viewport_rgb=paint_rgb)
    for ob in WALLS:
        assign_object_material(ob, M_WP)
        project_uv(ob, 1.6, uv_space_for(ob))
    for ob in CEILINGS:
        assign_object_material(ob, M_CE)
        project_uv(ob, 1.0, uv_space_for(ob))
    for ob in CARPETS:
        assign_object_material(ob, M_CP)
        project_uv(ob, 1.0, uv_space_for(ob))
    for ob in PAINTS:
        assign_object_material(ob, M_PT)
        project_uv(ob, 0.5, uv_space_for(ob))
    # opal globes: lit glass look for preview, same geometry
    opal = bpy.data.materials.get('Glass_OpalBulb')
    if opal is not None and principled(opal) is not None:
        p = principled(opal)
        p.inputs['Base Color'].default_value = (0.92, 0.93, 0.85, 1.0)
        p.inputs['Roughness'].default_value = 0.35
        p.inputs['Emission Color'].default_value = (1.0, 0.97, 0.82, 1.0)
        p.inputs['Emission Strength'].default_value = 1.6
    log('materials assigned: V3B_Wallpaper/Carpet/PopcornCeiling/PaintSatin')
    return {'wallpaper': (wp_b, wp_n, wp_r), 'carpet': (cp_b, cp_n, cp_r), 'ceiling': (ce_b, ce_n, ce_r), 'paint': (None, pt_n, pt_r)}


# ----------------------------------------------------------------------------- geometry pass
def add_bevel(ob, width, segments=1, angle=50.0):
    for m in ob.modifiers:
        if m.type == 'BEVEL':
            m.width = width
            m.segments = segments
            return m
    m = ob.modifiers.new('Bevel', 'BEVEL')
    m.width = width
    m.segments = segments
    m.limit_method = 'ANGLE'
    m.angle_limit = math.radians(angle)
    if not any(x.type == 'WEIGHTED_NORMAL' for x in ob.modifiers):
        ob.modifiers.new('WeightedNormal', 'WEIGHTED_NORMAL')
    return m


def smooth_by_angle(ob, angle_deg=38.0):
    me = ob.data
    if me.is_editmode:
        return
    bm = bmesh.new()
    bm.from_mesh(me)
    for f in bm.faces:
        f.smooth = True
    thr = math.radians(angle_deg)
    for e in bm.edges:
        if len(e.link_faces) == 2:
            a, b = e.link_faces
            if a.normal.angle(b.normal, 0.0) > thr:
                e.smooth = False
    bm.to_mesh(me)
    bm.free()


def geometry_pass():
    touched = []
    for ob in scene.objects:
        if ob.type != 'MESH' or ob.name.endswith('-colonly'):
            continue
        n = ob.name
        if n.startswith('Stair_Step_'):
            add_bevel(ob, 0.004); touched.append(n)
        elif n.startswith('Carpet_Tread_'):
            add_bevel(ob, 0.012, 2); touched.append(n)
        elif n.startswith(('Newel_Post', 'Newel_WoodCap')):
            add_bevel(ob, 0.004, 2); smooth_by_angle(ob); touched.append(n)
        elif n in ('Walnut_Handrail', 'White_LowerRail', 'Landing_Handrail'):
            add_bevel(ob, 0.009, 2); smooth_by_angle(ob, 60); touched.append(n)
        elif n.startswith(('Main_CeilingRose', 'Rear_CeilingRose', 'Stairs_CeilingRose')):
            add_bevel(ob, 0.003, 1); smooth_by_angle(ob); touched.append(n)
        elif n.startswith(('Main_OpalGlobe', 'Rear_OpalGlobe', 'Stairs_OpalGlobe')):
            smooth_by_angle(ob, 80); touched.append(n)
        elif 'Spindle' in n or 'BrassKnob' in n:
            smooth_by_angle(ob, 45); touched.append(n)
        elif n.startswith(('Skirting_', 'Entry_Casing', 'Entry_Jamb', 'Exit_Casing', 'Exit_Jamb')):
            add_bevel(ob, 0.005, 2); touched.append(n)
        elif n.endswith('Door_Leaf') or n.startswith(('Entry_RaisedPanel', 'Exit_RaisedPanel')):
            add_bevel(ob, 0.004, 2); touched.append(n)
    log('bevel/smooth touched %d objects' % len(touched))
    fix_stairwell_opening()
    marker = bpy.data.objects.get('AssetVersion_v3b')
    if marker is None:
        marker = bpy.data.objects.new('AssetVersion_v3b', None)
        marker.empty_display_type = 'PLAIN_AXES'
        marker.empty_display_size = 0.1
        marker['asset_version'] = 'v3b'
        marker['material_override'] = 'skip'
        marker['stairwell_repair'] = 'baked'
        (bpy.data.collections.get('80_Game_Anchors') or scene.collection).objects.link(marker)
        log('added AssetVersion_v3b marker (runtime can skip the material override and stairwell rebox)')


def _resize_box(ob, x_range=None, y_range=None, z_range=None):
    """Resize a simple axis-aligned box object by scaling about its centre (world ranges in metres)."""
    if ob is None:
        return
    lo, hi = None, None
    pts = [ob.matrix_world @ v.co for v in ob.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)])
    hi = Vector([max(p[i] for p in pts) for i in range(3)])
    size = hi - lo
    for axis, rng in enumerate((x_range, y_range, z_range)):
        if rng is None or size[axis] < 1e-6:
            continue
        new_size = rng[1] - rng[0]
        ob.scale[axis] *= new_size / size[axis]
        centre_now = (lo[axis] + hi[axis]) * 0.5
        ob.location[axis] += (rng[0] + rng[1]) * 0.5 - centre_now
    ob.location = ob.location


def fix_stairwell_opening():
    """Bake the runtime stairwell repair into the model: the ceiling opening's east edge moves
    from x=-1.69 to x=-1.48 so the upper banister is no longer buried in the ceiling."""
    east = -1.48
    pairs = {
        'Ceiling_Main': dict(x_range=(east, 3.36)),
        'Ceiling_FrontLeft': dict(x_range=(-3.36, east)),
        'Ceiling_RearLeft': dict(x_range=(-3.36, east)),
        'Ceiling_Stairwell': dict(x_range=(-3.36, east)),
        'Stairwell_UpperEast': dict(x_range=(east - 0.16, east)),
        'Stairwell_UpperFront': dict(x_range=(-3.36, east)),
        'Stairwell_UpperRear': dict(x_range=(-3.2, east)),
    }
    for name, kw in pairs.items():
        for suffix in ('', '-colonly'):
            _resize_box(bpy.data.objects.get(name + suffix), **kw)
    refresh()
    coll = bpy.data.collections.get('04_Trim') or scene.collection
    paint = bpy.data.materials.get('V3B_PaintSatin') or bpy.data.materials.get('Paint_OffWhite')
    bm = bmesh.new()
    _box(bm, (0.08, 5.20, 0.10), (east - 0.01, 0.01, 2.80))
    fascia = _finish_mesh(bm, 'Stair_OpeningFascia', [paint], coll)
    add_bevel(fascia, 0.004, 1)
    log('stairwell opening widened to x=%.2f on ceilings/upper walls (+collision), fascia trim added' % east)
    if DO_STRINGER:
        stringer_and_sealed_door()


def _box(bm, size, center, rot=(0, 0, 0), mat_index=0):
    r = bmesh.ops.create_cube(bm, size=1.0)
    M = Matrix.Translation(Vector(center)) @ Euler(rot, 'XYZ').to_matrix().to_4x4() @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    bmesh.ops.transform(bm, matrix=M, verts=r['verts'])
    for v in r['verts']:
        for f in v.link_faces:
            f.material_index = mat_index
    return r['verts']


def _sphere(bm, radius, center, mat_index=0):
    r = bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=8, radius=radius)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector(center)), verts=r['verts'])
    for v in r['verts']:
        for f in v.link_faces:
            f.material_index = mat_index
            f.smooth = True
    return r['verts']


def _finish_mesh(bm, name, materials, collection, uv_tile=0.5):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.normal_update()
    uv_layer = bm.loops.layers.uv.new('UVMap')
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            co = l.vert.co
            uv = (co.y, co.z) if ax == 0 else ((co.x, co.z) if ax == 1 else (co.x, co.y))
            l[uv_layer].uv = (uv[0] / uv_tile, uv[1] / uv_tile)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in materials:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    return ob


def stringer_and_sealed_door():
    """Painted stringer along the nosing line (closes the stepped side and the nook under the
    landing) plus the sealed closet door the user asked to keep: no handle use, paper seals."""
    coll = bpy.data.collections.get('02_Stairs_Detail') or scene.collection
    paint = bpy.data.materials.get('V3B_PaintSatin') or bpy.data.materials.get('Paint_OffWhite')
    brass = bpy.data.materials.get('Metal_AgedBrass')
    paper = bpy.data.materials.get('V3B_PaperSeal')
    if paper is None:
        paper = new_material('V3B_PaperSeal')
        pp = principled(paper)
        pp.inputs['Base Color'].default_value = (0.78, 0.70, 0.50, 1.0)
        pp.inputs['Roughness'].default_value = 0.9
        paper.diffuse_color = (0.78, 0.70, 0.50, 1.0)
    stamp = bpy.data.materials.get('V3B_SealStamp')
    if stamp is None:
        stamp = new_material('V3B_SealStamp')
        sp = principled(stamp)
        sp.inputs['Base Color'].default_value = (0.55, 0.06, 0.05, 1.0)
        sp.inputs['Roughness'].default_value = 0.85
        stamp.diffuse_color = (0.55, 0.06, 0.05, 1.0)
    # stringer panel
    bm = bmesh.new()
    prof = [(-2.60, 0.0), (2.42, 0.0), (2.42, 2.705), (1.32, 2.705), (-2.60, 0.195)]
    x0, x1 = -1.862, -1.846
    a = [bm.verts.new((x0, y, z)) for y, z in prof]
    b = [bm.verts.new((x1, y, z)) for y, z in prof]
    faces = [bm.faces.new(a), bm.faces.new(list(reversed(b)))]
    n = len(a)
    for i in range(n):
        faces.append(bm.faces.new((a[(i + 1) % n], a[i], b[i], b[(i + 1) % n])))
    stringer = _finish_mesh(bm, 'Stair_Stringer_East', [paint], coll)
    add_bevel(stringer, 0.004, 1)
    # collision for the closed stair side / nook
    bm = bmesh.new()
    _box(bm, (0.03, 5.02, 2.72), (-1.855, -0.09, 1.36))
    colb = _finish_mesh(bm, 'Stair_Stringer_East-colonly', [], bpy.data.collections.get('90_Static_Collision') or coll)
    colb.hide_render = True
    colb.display_type = 'WIRE'
    # sealed door on the panel under the landing (faces +x)
    bm = bmesh.new()
    xf = -1.846
    _box(bm, (0.030, 0.70, 1.90), (xf + 0.015, 2.01, 0.97), mat_index=0)            # leaf
    for z in (0.45, 1.15, 1.62):
        _box(bm, (0.010, 0.42, 0.30), (xf + 0.034, 2.01, z), mat_index=0)            # raised panels
    _box(bm, (0.018, 0.06, 2.00), (xf + 0.009 + 0.012, 1.63, 1.00), mat_index=0)    # casing
    _box(bm, (0.018, 0.06, 2.00), (xf + 0.009 + 0.012, 2.39, 1.00), mat_index=0)
    _box(bm, (0.018, 0.82, 0.06), (xf + 0.009 + 0.012, 2.01, 1.98), mat_index=0)
    door = _finish_mesh(bm, 'StairCloset_Door', [paint], coll)
    add_bevel(door, 0.003, 1)
    bm = bmesh.new()
    _sphere(bm, 0.028, (xf + 0.065, 2.29, 1.02))
    r = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=14, radius1=0.03, radius2=0.03, depth=0.03)
    bmesh.ops.transform(bm, matrix=Matrix.Translation(Vector((xf + 0.045, 2.29, 1.02))) @ Euler((0, math.pi / 2, 0)).to_matrix().to_4x4(), verts=r['verts'])
    for v in r['verts']:
        for f in v.link_faces:
            f.smooth = True
    knob = _finish_mesh(bm, 'StairCloset_Knob', [brass] if brass else [paint], coll)
    # paper seals: an X across the latch edge and one strip across the top edge
    bm = bmesh.new()
    for (cy, cz, rot) in ((2.33, 1.05, math.radians(35)), (2.33, 1.05, math.radians(-35)), (2.02, 1.92, 0.0)):
        _box(bm, (0.004, 0.065, 0.50), (xf + 0.047, cy, cz), rot=(rot, 0, 0), mat_index=0)
        _box(bm, (0.002, 0.045, 0.045), (xf + 0.050, cy, cz), rot=(rot, 0, 0), mat_index=1)
    seals = _finish_mesh(bm, 'StairCloset_Seals', [paper, stamp], coll)
    # game anchor for the knocking event / audio emitter
    anchors = bpy.data.collections.get('80_Game_Anchors') or coll
    anc = bpy.data.objects.new('StairClosetDoorAnchor', None)
    anc.empty_display_type = 'PLAIN_AXES'
    anc.empty_display_size = 0.25
    anc.location = (-1.80, 2.01, 1.0)
    anc['event'] = 'sealed_door_knock'
    anc['interaction'] = 'none'
    anchors.objects.link(anc)
    log('added Stair_Stringer_East (+collision), sealed StairCloset_Door with knob, 3 paper seals, StairClosetDoorAnchor')


# ----------------------------------------------------------------------------- lighting pass (preview)
def lighting_pass():
    for name in ('PreviewFill', 'RearBounce', 'CRT_Green_AreaFill'):
        ob = bpy.data.objects.get(name)
        if ob is not None:
            ob.hide_render = True
    for name, energy, color in (('Main_PointLight', MAIN_W, (0.93, 0.95, 0.76)), ('Rear_PointLight', REAR_W, (0.93, 0.95, 0.76)),
                                ('CRT_Green_PointLight', CRT_W, (0.25, 1.0, 0.35)), ('Stairs_PointLight', 0.0, (0.93, 0.95, 0.76))):
        ob = bpy.data.objects.get(name)
        if ob is not None and ob.type == 'LIGHT':
            ob.data.energy = energy
            ob.data.color = color
            ob.data.shadow_soft_size = 0.10
    for name in ('Main_OpalGlobe', 'Rear_OpalGlobe', 'Stairs_OpalGlobe'):
        ob = bpy.data.objects.get(name)
        if ob is not None:
            ob.visible_shadow = False
    world = scene.world
    if world is None:
        world = bpy.data.worlds.new('V3B_World')
        scene.world = world
    try:
        if not world.node_tree:
            world.use_nodes = True
    except Exception:
        pass
    nt = world.node_tree
    out = next((n for n in nt.nodes if n.type == 'OUTPUT_WORLD'), None) or nt.nodes.new('ShaderNodeOutputWorld')
    bg = next((n for n in nt.nodes if n.type == 'BACKGROUND'), None)
    if bg is not None:
        bg.inputs[0].default_value = (0.0, 0.0, 0.0, 1.0)
        bg.inputs[1].default_value = 0.0
    vol = nt.nodes.new('ShaderNodeVolumeScatter')
    vol.inputs['Density'].default_value = HAZE
    vol.inputs['Anisotropy'].default_value = 0.35
    nt.links.new(vol.outputs['Volume'], out.inputs['Volume'])
    vs = scene.view_settings
    try:
        vs.view_transform = 'AgX'
        vs.look = 'AgX - Medium High Contrast'
    except Exception as e:
        log('view transform fallback:', e)
    vs.exposure = EXPOSURE
    vs.gamma = 1.0
    log('lighting: main %.1fW, rear %.1fW, CRT %.1fW, fills off, haze %.3f, AgX exposure %.2f' % (MAIN_W, REAR_W, CRT_W, HAZE, EXPOSURE))


# ----------------------------------------------------------------------------- render
def setup_cycles(samples):
    scene.render.engine = 'CYCLES'
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type = 'OPTIX'
        prefs.get_devices()
        for d in prefs.devices:
            d.use = d.type != 'CPU'
        scene.cycles.device = 'GPU'
    except Exception as e:
        log('GPU setup failed:', e)
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.render.use_persistent_data = True


def camera(name, loc, target, lens=22.0):
    ob = bpy.data.objects.get(name)
    if ob is None:
        cd = bpy.data.cameras.new(name)
        cd.lens = lens
        cd.clip_start = 0.05
        ob = bpy.data.objects.new(name, cd)
        (bpy.data.collections.get('70_Preview_Cameras') or scene.collection).objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    ob['exclude_export'] = True
    return ob


VIEWS = [
    ('View_TV_Stairs', None, None),
    ('View_CRT_FromStairs', None, None),
    ('View_RightPassage', None, None),
    ('View_NPC_Exit', None, None),
    ('View_Basement_Entrance', None, None),
    ('V3B_View_Low_CRT', (-0.6, 1.9, 0.75), (2.0, -3.7, 0.85)),
    ('V3B_View_Globe', (-0.4, 0.4, 1.25), (0.3, -1.5, 2.45)),
    ('V3B_View_Stair_Nook', (0.7, 2.0, 1.35), (-2.0, 1.9, 1.2)),
    ('V3B_Closeup_Wallpaper', (-0.55, 1.35, 1.45), (-0.45, 2.42, 1.35)),
    ('V3B_Closeup_Stairs', (-1.25, -2.35, 0.95), (-2.45, -1.95, 0.45)),
    ('V3B_Closeup_Ceiling', (0.9, -0.9, 1.5), (0.3, -1.5, 2.6)),
]
CLOSEUP_BOOST = 1.7


def render_views(prefix):
    for name, loc, target in VIEWS:
        if VIEW_FILTER and name not in VIEW_FILTER:
            continue
        cam = bpy.data.objects.get(name) if loc is None else camera(name, loc, target)
        if cam is None:
            log('missing camera', name)
            continue
        scene.camera = cam
        scene.render.resolution_x, scene.render.resolution_y = 1600, 900
        path = os.path.join(OUT, '%s_%s.png' % (prefix, name))
        scene.render.filepath = path
        refresh()
        t = time.time()
        base_exposure = scene.view_settings.exposure
        if name.startswith('V3B_Closeup'):
            scene.view_settings.exposure = base_exposure + CLOSEUP_BOOST
        with bpy.context.temp_override(scene=scene):
            bpy.ops.render.render(write_still=True)
        scene.view_settings.exposure = base_exposure
        log('rendered %s in %.1fs' % (os.path.basename(path), time.time() - t))


# ============================================================================= MAIN
t0 = time.time()
if DO_MAT:
    materials_pass()
if DO_GEO:
    geometry_pass()
if DO_LIGHT:
    lighting_pass()
refresh()
if SAVE and (DO_MAT or DO_GEO):
    out_blend = os.path.join(OUT, 'Basement_Loop_%s.blend' % TAG)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend, copy=True, compress=True)
    log('saved', out_blend)
setup_cycles(SAMPLES)
if 'views' in RENDER:
    render_views(TAG)
log('total %.1fs' % (time.time() - t0))
with open(os.path.join(OUT, 'log_%s.txt' % TAG), 'w', encoding='utf-8') as f:
    f.write('\n'.join(LOG))
