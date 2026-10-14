"""Package thumbnails only; geometry was already made visibly through Blender MCP."""
import bpy,json
from pathlib import Path
root=Path(r'D:/aphasia/outputs/blender_basement_loop_v2')
sources=json.loads((root/'asset_preview_sources.json').read_text(encoding='utf-8'))
result=[]
for name,path in sources.items():
    asset=bpy.data.collections[name]
    with bpy.context.temp_override(id=asset):bpy.ops.ed.lib_id_load_custom_preview(filepath=path)
    p=asset.preview_ensure()
    result.append({'name':name,'size':list(p.image_size),'custom':p.is_image_custom})
bpy.ops.wm.save_as_mainfile(filepath=str(root/'asset_library'/'Basement_All_Props_v2.blend'),compress=True)
(root/'asset_preview_validation.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('PERSISTENT_CUSTOM_PREVIEWS',result)
