"""Original, editable basement props. Run build_assets() inside live Blender.

This module performs no work on import. It never resets, deletes, saves, exports,
changes selection, or changes the active scene. All geometry is metre scale,
front -Y, floor Z=0; each returned collection contains a single assembly root.
Call build_assets(scene=bpy.context.scene), then instance the returned collections.
"""

import math
import uuid
from pathlib import Path

import bpy
from mathutils import Vector


TEXTURE_DIR = Path(r"D:\aphasia\outputs\blender_subliminal\textures")
CATALOG_ID = str(uuid.uuid5(uuid.NAMESPACE_URL, "aphasia/basement/electronics-details"))


def build_assets(scene=None):
    """Return {crt, switch, box, frame, vhs: newly created asset Collection}.

    Collections are linked to the supplied scene, but all assemblies start at
    the origin. For dressing, instance a collection and move its instance, or
    move its root if using the collection directly. Never transform both.
    The caller owns library saving, asset previews, and export.
    """
    scene = scene or bpy.context.scene
    assets = {}
    materials = {}

    def material(key, color, roughness=0.65, metal=0.0):
        name = "APH2_" + key
        mat = bpy.data.materials.get(name)
        if mat is not None:
            materials[key] = mat
            return mat
        mat = bpy.data.materials.new(name)
        mat.diffuse_color = (*color, 1.0)
        mat.use_nodes = True
        bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metal
        materials[key] = mat
        return mat

    material("Aged_ABS", (0.39, 0.345, 0.26), 0.63)
    material("ABS_Edge", (0.29, 0.254, 0.193), 0.72)
    material("ABS_Rear", (0.215, 0.204, 0.175), 0.77)
    material("Vent_Shadow", (0.019, 0.018, 0.014), 0.92)
    material("Rubber", (0.026, 0.029, 0.026), 0.89)
    material("Knob_Charcoal", (0.061, 0.062, 0.054), 0.51)
    material("Steel", (0.29, 0.295, 0.26), 0.39, 0.75)
    material("Warm_Ivory", (0.63, 0.589, 0.459), 0.61)
    material("Cardboard", (0.306, 0.183, 0.08), 0.94)
    material("Cardboard_Edge", (0.171, 0.098, 0.044), 0.99)
    material("Old_Tape", (0.365, 0.249, 0.125), 0.45)
    material("Paper_Blank", (0.58, 0.53, 0.398), 0.94)
    material("Frame_Walnut", (0.076, 0.035, 0.013), 0.46)
    material("VHS_Plastic", (0.025, 0.029, 0.028), 0.63)
    material("VHS_Window", (0.035, 0.051, 0.052), 0.17)

    # Direct Emission -> Output is visually unlit in Blender. This exporter
    # writes emissive PBR, so the Godot video component must override the surface
    # with its unshaded material. No footage or narrative content is embedded.
    screen_mat = bpy.data.materials.get("APH2_CRT_Video_Unlit")
    if screen_mat is None:
        screen_mat = bpy.data.materials.new("APH2_CRT_Video_Unlit")
        screen_mat.use_nodes = True
        output = next(n for n in screen_mat.node_tree.nodes if n.type == "OUTPUT_MATERIAL")
        emission = screen_mat.node_tree.nodes.new("ShaderNodeEmission")
        emission.inputs["Color"].default_value = (0.014, 0.024, 0.02, 1.0)
        emission.inputs["Strength"].default_value = 0.3
        screen_mat.node_tree.links.new(emission.outputs[0], output.inputs["Surface"])
        screen_mat.diffuse_color = (0.0042, 0.0072, 0.006, 1.0)
        screen_mat["runtime_usage"] = "Replace this surface material with an unshaded SubViewportTexture material; UV0 spans 0..1."
    materials["Screen"] = screen_mat

    art_mat = bpy.data.materials.get("APH2_Framed_Art")
    if art_mat is None:
        art_mat = material("Framed_Art", (0.28, 0.31, 0.24), 0.95)
        image_path = TEXTURE_DIR / "framed_art.png"
        if image_path.is_file():
            image = bpy.data.images.load(str(image_path), check_existing=True)
            tex = art_mat.node_tree.nodes.new("ShaderNodeTexImage")
            tex.image = image
            bsdf = next(n for n in art_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            art_mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    materials["Art"] = art_mat

    def assembly(key, title, dimensions, description):
        col = bpy.data.collections.new("APH2_Asset_" + title)
        scene.collection.children.link(col)
        root = bpy.data.objects.new("APH2_" + title + "_Root", None)
        col.objects.link(root)
        root.empty_display_size = 0.08
        root["nominal_dimensions_m"] = list(dimensions)
        root["front_direction"] = "-Y"
        root["origin_convention"] = "Bottom centre, floor Z=0"
        root["asset_key"] = key
        col["root_object"] = root.name
        col["nominal_dimensions_m"] = list(dimensions)
        col.asset_mark()
        col.asset_data.description = description + " Original editable meshes; metres; floor Z=0; front -Y."
        col.asset_data.author = "Aphasia"
        col.asset_data.catalog_id = CATALOG_ID
        for tag in ("Basement", "Editable", "Original", "Metre scale"):
            col.asset_data.tags.new(tag)
        assets[key] = col
        return col, root

    def mesh(col, root, name, vertices, faces, mat, bevel=0.0, smooth=False, uv=None):
        data = bpy.data.meshes.new(name + "_Mesh")
        data.from_pydata(vertices, [], faces)
        data.materials.append(materials[mat])
        data.update()
        obj = bpy.data.objects.new(name, data)
        col.objects.link(obj)
        obj.parent = root
        layer = data.uv_layers.new(name="UVMap")
        for poly in data.polygons:
            poly.use_smooth = smooth
            axis = max(range(3), key=lambda i: abs(poly.normal[i]))
            for loop_index in poly.loop_indices:
                vi = data.loops[loop_index].vertex_index
                v = data.vertices[vi].co
                layer.data[loop_index].uv = uv[vi] if uv is not None else (
                    (v.y, v.z) if axis == 0 else (v.x, v.z) if axis == 1 else (v.x, v.y))
        if bevel:
            mod = obj.modifiers.new("Small physical edge radius", "BEVEL")
            mod.width = bevel
            mod.segments = 2
        return obj

    def box(col, root, name, centre, size, mat, bevel=0.0):
        x, y, z = centre
        a, b, c = (s * 0.5 for s in size)
        vertices = [(x-a, y-b, z-c), (x+a, y-b, z-c), (x+a, y+b, z-c), (x-a, y+b, z-c),
                    (x-a, y-b, z+c), (x+a, y-b, z+c), (x+a, y+b, z+c), (x-a, y+b, z+c)]
        faces = [(3, 2, 1, 0), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)]
        return mesh(col, root, name, vertices, faces, mat, bevel)

    def cylinder(col, root, name, centre, radius, depth, mat, axis=(0, 0, 1), sides=16):
        centre, axis = Vector(centre), Vector(axis).normalized()
        helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((0, 1, 0))
        u = axis.cross(helper).normalized()
        v = axis.cross(u).normalized()
        vertices = [tuple(centre + axis * end * depth / 2 + radius * (u * math.cos(2*math.pi*j/sides) + v * math.sin(2*math.pi*j/sides)))
                    for end in (-1, 1) for j in range(sides)]
        faces = [tuple(reversed(range(sides))), tuple(range(sides, sides*2))]
        faces += [(j, (j+1) % sides, (j+1) % sides+sides, j+sides) for j in range(sides)]
        obj = mesh(col, root, name, vertices, faces, mat)
        for poly in obj.data.polygons[2:]:
            poly.use_smooth = True
        return obj

    def tube(col, root, name, points, radius, mat, sides=8):
        points = [Vector(p) for p in points]
        vertices = []
        for i, p in enumerate(points):
            tangent = (points[min(i+1, len(points)-1)] - points[max(i-1, 0)]).normalized()
            helper = Vector((0, 0, 1)) if abs(tangent.z) < 0.9 else Vector((0, 1, 0))
            u = tangent.cross(helper).normalized()
            v = tangent.cross(u).normalized()
            for j in range(sides):
                angle = 2 * math.pi * j / sides
                vertices.append(tuple(p + radius * (math.cos(angle)*u + math.sin(angle)*v)))
        faces = [tuple(reversed(range(sides))), tuple((len(points)-1)*sides+j for j in range(sides))]
        for i in range(len(points)-1):
            for j in range(sides):
                faces.append((i*sides+j, i*sides+(j+1) % sides, (i+1)*sides+(j+1) % sides, (i+1)*sides+j))
        return mesh(col, root, name, vertices, faces, mat, smooth=True)

    # CRT: deep tapering tube housing, bezel aperture, bowed picture surface.
    col, root = assembly("crt", "CRT_TV", (0.65, 0.54, 0.55),
                         "1990s warm-grey CRT television with 4:3 curved UV-mapped video surface, side speaker, tactile controls, vents and coiled rear cable.")
    front = [(-.325, -.248, .061), (.325, -.248, .061), (.325, -.248, .55), (-.325, -.248, .55)]
    rear = [(-.238, .255, .077), (.238, .255, .077), (.238, .255, .477), (-.238, .255, .477)]
    aperture = [(-.289, -.254, .139), (.189, -.254, .139), (.189, -.254, .502), (-.289, -.254, .502)]
    shell_faces = [(4,5,1,0), (5,6,2,1), (6,7,3,2), (7,4,0,3), (7,6,5,4)]
    shell_faces += [(i, (i+1) % 4, 8+(i+1) % 4, 8+i) for i in range(4)]
    mesh(col, root, "CRT_Tapered_Housing", front+rear+aperture, shell_faces, "Aged_ABS", .008)
    inner = [(-.283, -.254, .144), (.183, -.254, .144), (.183, -.254, .4935), (-.283, -.254, .4935)]
    mesh(col, root, "CRT_Dark_Inner_Bezel", aperture+inner,
         [(i, (i+1) % 4, 4+(i+1) % 4, 4+i) for i in range(4)], "Vent_Shadow")
    verts, uvs, faces = [], [], []
    nx, nz = 32, 24
    for j in range(nz+1):
        v = j/nz
        b = 2*v-1
        for i in range(nx+1):
            u = i/nx
            a = 2*u-1
            verts.append((-.05 + a*.233, -.255 - .020*(1-a*a)*(1-b*b), .31875+b*.17475))
            uvs.append((u,v))
    for j in range(nz):
        for i in range(nx):
            a = j*(nx+1)+i
            faces.append((a,a+1,a+nx+2,a+nx+1))
    screen = mesh(col, root, "Screen_Video", verts, faces, "Screen", smooth=True, uv=uvs)
    screen["screen_aspect_ratio"] = "4:3"
    screen["screen_dimensions_m"] = [.466, .3495]
    screen["surface_role"] = "video"
    screen["godot_video_source"] = "VideoStreamPlayer -> SubViewport -> unshaded material; native .ogv media supplied later"
    root["video_screen_object"] = screen.name
    root["video_material"] = screen_mat.name
    root["screen_local_centre"] = [-.05, -.275, .31875]
    col["video_screen_object"] = screen.name
    # Rear cover seam and side ventilation are separate editable pieces.
    box(col, root, "CRT_Rear_Service_Cover", (0,.257,.275), (.402,.007,.327), "ABS_Rear", .012)
    for i in range(11):
        box(col, root, "CRT_Rear_Vent_%02d" % i, (0,.262,.202+i*.016), (.303,.002,.006), "Vent_Shadow", .001)
    for i in range(9):
        y = -.026 + i*.023
        # Right wall tapers from x=.325 to .238 over its depth.
        x = .325-(y+.248)/.503*.087 + .0005
        slope = .087/.503
        mesh(col, root, "CRT_Side_Vent_%02d" % i,
             [(x+.004*slope,y-.004,.2525), (x-.004*slope,y+.004,.2525),
              (x-.004*slope,y+.004,.3795), (x+.004*slope,y-.004,.3795)],
             [(0,1,2,3)], "Vent_Shadow")
    for i in range(13):
        box(col, root, "CRT_Speaker_Slot_%02d" % i, (.253,-.254,.269+i*.015), (.077,.004,.0045), "Vent_Shadow", .001)
    cylinder(col, root, "CRT_Channel_Knob", (.252,-.264,.186), .020,.021,"Knob_Charcoal",axis=(0,-1,0),sides=24)
    box(col, root, "CRT_Knob_Indicator", (.252,-.276,.192), (.0028,.002,.012), "Warm_Ivory", .001)
    for i in range(3):
        box(col, root, "CRT_Control_%d" % i, (-.128+i*.046,-.257,.103), (.026,.008,.014), "ABS_Edge", .002)
    cylinder(col, root, "CRT_Power_Button", (.249,-.257,.103), .009,.009,"Knob_Charcoal",axis=(0,-1,0))
    cylinder(col, root, "CRT_Unlit_Indicator", (.279,-.255,.105), .0024,.003,"Rubber",axis=(0,-1,0),sides=10)
    box(col, root, "CRT_Blank_Maker_Plate", (-.212,-.252,.095), (.072,.003,.014), "ABS_Edge", .002)
    for x in (-.245,.245):
        for y in (-.169,.169):
            box(col, root, "CRT_Rubber_Foot", (x,y,.03), (.083,.079,.06), "Rubber", .006)
    for x in (-.178,.178):
        for z in (.138,.416):
            cylinder(col, root, "CRT_Cover_Screw", (x,.263,z), .0035,.002,"Steel",axis=(0,1,0),sides=10)
    tube(col, root, "CRT_Coiled_Power_Cable", [( .12,.259,.137),(.10,.261,.091),(.068,.256,.046),(.012,.247,.036),
         (-.065,.23,.036),(-.124,.187,.034),(-.132,.13,.033),(-.092,.1,.032),(-.029,.119,.032),
         (-.014,.17,.034),(-.066,.198,.035),(-.132,.196,.035),(-.177,.166,.035)], .0035,"Rubber")
    box(col, root, "CRT_Power_Plug", (-.185,.155,.035), (.027,.044,.022), "Rubber", .003)

    # Switch origin is bottom centre, back at +Y; face points -Y.
    col, root = assembly("switch", "Wall_Switch", (.081,.026,.126),
                         "Yellowed wall toggle switch with recessed toggle and two slotted screws; mount with its back against the wall.")
    box(col, root, "Switch_Back_Shadow", (0,.006,.063), (.076,.009,.121), "ABS_Edge", .005)
    box(col, root, "Switch_Faceplate", (0,0,.063), (.081,.01,.126), "Warm_Ivory", .006)
    box(col, root, "Switch_Toggle_Socket", (0,-.006,.063), (.019,.003,.027), "Vent_Shadow", .002)
    toggle=box(col, root, "Switch_Toggle", (0,-.009,.064), (.010,.012,.020), "Warm_Ivory", .002)
    # Mesh is modelled in root coordinates, so rotation around its origin is
    # intentionally avoided here; runtime animation may create a local pivot.
    toggle["interactive_role"]="light_switch"
    for z in (.017,.109):
        cylinder(col, root, "Switch_Screw", (0,-.006,z), .0034,.002,"Steel",axis=(0,-1,0),sides=12)
        box(col, root, "Switch_Screw_Slot", (0,-.0075,z), (.0047,.001,.0007),"Vent_Shadow")

    col, root = assembly("box", "Cardboard_Box", (.44,.324,.288),
                         "Closed worn cardboard storage box with lid flaps, folded edges, old packing tape and a blank paper label.")
    box(col, root, "Box_Main", (0,0,.14), (.44,.32,.28),"Cardboard",.003)
    for side in (-1,1):
        box(col, root, "Box_Lid_Flap", (0,side*.0805,.283),(.438,.157,.004),"Cardboard",.001)
    box(col, root, "Box_Lid_Centre_Seam", (0,0,.284),(.436,.0025,.002),"Cardboard_Edge")
    box(col, root, "Box_Tape_Top", (0,0,.287),(.061,.32,.002),"Old_Tape",.0006)
    for side in (-1,1):
        box(col, root, "Box_Tape_End", (0,side*.161,.247),(.061,.0015,.078),"Old_Tape",.0005)
    box(col, root, "Box_Blank_Label", (-.118,-.1608,.175),(.119,.001,.057),"Paper_Blank",.001)
    for x in (-.219,.219):
        box(col, root, "Box_Fold_Edge", (x,-.1605,.14),(.0015,.001,.271),"Cardboard_Edge")

    col, root = assembly("frame", "Framed_Picture", (.34,.026,.42),
                         "Small dark walnut picture frame with separate removable picture surface; uses the project's original framed-art texture if present.")
    box(col, root, "Frame_Backboard", (0,.009,.21),(.329,.006,.409),"Cardboard_Edge")
    for x in (-.16,.16):
        box(col, root,"Frame_Vertical_Rail",(x,0,.21),(.02,.026,.42),"Frame_Walnut",.002)
    for z in (.01,.41):
        box(col, root,"Frame_Horizontal_Rail",(0,0,z),(.30,.026,.02),"Frame_Walnut",.002)
    box(col, root,"Frame_Paper_Mat",(0,-.009,.21),(.30,.002,.38),"Paper_Blank")
    picture = mesh(col,root,"Frame_Picture_Surface",[(-.13,-.0105,.038),(.13,-.0105,.038),(.13,-.0105,.382),(-.13,-.0105,.382)],
                   [(0,1,2,3)],"Art",uv=[(0,0),(1,0),(1,1),(0,1)])
    root["replaceable_picture_object"] = picture.name

    col, root = assembly("vhs", "VHS_Stack", (.19,.107,.085),
                         "Three blank-labelled VHS cassettes with recessed reel windows, spool centres, screw heads and ribbed edges; each cassette is independently editable.")
    for level in range(3):
        z = level*.028
        box(col,root,"VHS_%d_Body"%level,(0,0,z+.013),(.188,.105,.026),"VHS_Plastic",.0015)
        box(col,root,"VHS_%d_Tape_Flap"%level,(0,-.0507,z+.015),(.181,.004,.022),"Knob_Charcoal",.0006)
        box(col,root,"VHS_%d_Spine_Label"%level,(0,.0528,z+.013),(.13,.001,.014),"Paper_Blank",.001)
        for x in (-.047,.047):
            box(col,root,"VHS_%d_Window"%level,(x,0,z+.027),(.066,.064,.001),"VHS_Window",.003)
            cylinder(col,root,"VHS_%d_Reel"%level,(x,0,z+.0276),.020,.0007,"ABS_Edge",sides=24)
            cylinder(col,root,"VHS_%d_Hub"%level,(x,0,z+.028),.007,.0006,"Paper_Blank",sides=12)
        box(col,root,"VHS_%d_Top_Label"%level,(0,.039,z+.0273),(.153,.017,.001),"Paper_Blank",.001)
        for x in (-.08,.08):
            for y in (-.037,.035):
                cylinder(col,root,"VHS_%d_Screw"%level,(x,y,z+.027),.0016,.001,"Steel",sides=8)
        for i in range(7):
            box(col,root,"VHS_%d_Edge_Rib_%d"%(level,i),(-.0945,-.031+i*.010,z+.013),(.001,.002,.017),"ABS_Rear")

    for key, col in assets.items():
        col["asset_version"] = "1.0"
        col["source_script"] = "build_crt_assets.py"
        col["license"] = "Original Aphasia project asset"
        root = next(obj for obj in col.objects if obj.parent is None)
        root["part_count"] = len(col.objects)-1
    return assets
