# CRT and detail assets

`build_crt_assets.py` is an original additive Blender builder. It has no scene reset,
delete, save, export, UI, render, selection or active-scene side effects. It only
creates materials, mesh objects, roots and asset collections when `build_assets()`
is called. It does not execute automatically when loaded. Syntax was checked with
Python `py_compile`; live Blender construction and image review belong to the root
task and have not been claimed as complete here.

```python
source = r"D:\aphasia\outputs\blender_basement_loop_v2\scripts\build_crt_assets.py"
namespace = {"__name__": "aphasia_crt_asset_builder"}
exec(compile(open(source, encoding="utf-8").read(), source, "exec"), namespace)
assets = namespace["build_assets"](scene=bpy.context.scene)
```

| Return key | New collection base name | Approximate XYZ dimensions (metres) |
|---|---|---|
| `crt` | `APH2_Asset_CRT_TV` | 0.65 × 0.54 × 0.55 |
| `switch` | `APH2_Asset_Wall_Switch` | 0.081 × 0.026 × 0.126 |
| `box` | `APH2_Asset_Cardboard_Box` | 0.44 × 0.324 × 0.288 |
| `frame` | `APH2_Asset_Framed_Picture` | 0.34 × 0.026 × 0.42 |
| `vhs` | `APH2_Asset_VHS_Stack` | 0.19 × 0.107 × 0.085 |

All assemblies face Blender -Y and have a bottom-centred root at Z=0. The switch
and picture are wall-mounted with their rear +Y face against the wall. Root and
collection metadata expose `nominal_dimensions_m`; these are nominal object
sizes, not collision guarantees. Minor details and bevels require measured bounds
when generating collision shapes. Repeated builder calls add new Blender-suffixed
IDs; they never replace prior objects. Read each collection's `root_object` for
its actual root name.

Each collection is asset-marked and uses catalog UUID
`10a21341-e5f9-5dd8-a738-85f8b2421dfe`. It is also available as the script's
`CATALOG_ID`; read `namespace["CATALOG_ID"]` when writing the catalog file.
Suggested catalog path: `Basement/Electronics and Details`.

## CRT video contract

- Screen object base name: **`Screen_Video`**. Its actual name is stored in the CRT
  collection and root under `video_screen_object`.
- Visible screen size: **0.466 × 0.3495 m**, exact **4:3**. 32 × 24 quad grid,
  20 mm convex tube bow. Normals face -Y. Screen UV0 spans 0–1, increasing left
  to right and bottom to top.
- Screen has its own material **`APH2_CRT_Video_Unlit`**, an Emission-to-Output
  shader, with a dark off-state and no image or video attached. The observed
  Blender exporter writes emissive PBR, not `KHR_materials_unlit`; the runtime
  override below is required despite the Blender material's name.
- Godot should override only this surface with an unshaded material that receives
  a `SubViewportTexture`. A `VideoStreamPlayer` in that viewport can play the
  future supplied `.ogv` file. Keep optional room-light contribution separate;
  the television asset contains no light or sound node.
- Root `screen_local_centre`: `[-0.05, -0.275, 0.31875]`. This is the bowed centre
  of the face, useful for a sound/light anchor in the root's local coordinates.
- All cassette labels and maker plates are blank. No new story text is embedded.

## Linking and dressing

The builder links asset source collections into the target scene at the origin.
Build them in a dedicated library scene, then make a collection-instance object
in the basement scene and transform the instance:

```python
instance = bpy.data.objects.new("Basement_CRT_Instance", None)
instance.instance_type = "COLLECTION"
instance.instance_collection = assets["crt"]
basement_scene.collection.objects.link(instance)
instance.location = (tv_x, tv_y, console_top_z)
instance.rotation_euler.z = math.pi  # Front faces +Y into the room.
```

For an editable assembly, link the collection and move only its root. Do not move
both the root and a collection instance. Source collections are not hidden by the
builder, because hiding a shared collection can also hide its instances. The
caller should preserve source collections in their separate scene.

The picture can reuse the existing original project `framed_art.png`. Save with
packed images or export with texture embedding. Other materials use portable
PBR constants and geometry, with no Blender-only procedural textures. The caller
owns previews, collision creation, glTF export and persistent library saving.
