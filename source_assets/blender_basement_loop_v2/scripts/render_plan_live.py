import bpy

def schedule():
    bl=bpy.app.driver_namespace['aphasia_basement_builder'];s=bl.scene
    route=s.objects['PREVIEW_ONLY_PlayerRoute'];route.data.splines[0].points[1].co.z=2.8
    previous_cam=s.camera;previous_res=(s.render.resolution_x,s.render.resolution_y)
    states={o:(o.hide_render,o.hide_get()) for o in s.objects}
    s.camera=s.objects['View_Plan_Top'];s.render.resolution_x=1100;s.render.resolution_y=1200
    for ob in s.objects:
        if ob.get('cutaway_hide') or ob.name.startswith(('Ceiling_','Stairwell_Upper')) or (ob.type=='MESH' and any(c.name=='06_Lighting' for c in ob.users_collection)):
            ob.hide_render=True
    route.hide_render=True;route.hide_set(True)
    route.hide_viewport=True;route['exclude_export']=True
    s.render.filepath=str(bl.OUT/'previews'/'03_Approved_Floorplan.png')
    def render_and_restore():
        try:bpy.ops.render.render(write_still=True)
        finally:
            for o,(r,h) in states.items():o.hide_render=r;o.hide_set(h)
            s.camera=previous_cam;s.render.resolution_x,s.render.resolution_y=previous_res
            bpy.ops.wm.save_as_mainfile(filepath=str(bl.OUT/'Basement_Loop_v2.blend'))
        return None
    bpy.app.timers.register(render_and_restore,first_interval=.5)

if __name__=='__main__':schedule()
