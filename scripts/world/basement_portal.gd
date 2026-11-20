class_name BasementPortal
extends Node3D
## Chapter one's portal (planner's design of 2026-10-31, after Viewfinder): through the X-ray's frame the player sees
## another world, the black water and the white door of the passage, and a frame held still for three seconds stays in
## the room. Fixed, it is everything the fixing eye saw through the frame, from where the other world begins on: the
## room in there is replaced by the other world as seen from wherever the player stands, a paper sticker runs where the
## frame's edge meets the walls, the floor and the ceiling, and a player who walks in there has left the room for the
## passage. A fixed portal stays until another frame is fixed.
## A portal that is used up (the run has gone through one) still fixes, but as a flat print of the white door pasted on
## the room: nobody walks into it.
## The other world is the opening's model in a viewport with a world of its own; its camera follows the player's through
## a fixed mapping that puts the fixing player at the passage's own start, so the picture does not jump when the stage
## changes to the passage.

const SHADER := preload("res://shaders/portal_window.gdshader")
const OTHER_WORLD_PATH := "res://assets/chapter1/Opening_WhiteDoor_v2.glb"
## How far in front of the fixing eye the other world begins, unless a wall stands nearer (`fix`).
const NEAR := 0.9
## The sticker's width as a share of the frame's height.
const BORDER := 0.03
## The other world is drawn at this share of the screen's size.
const PICTURE_SCALE := 0.75
## How far past `NEAR` a player's body must be to count as walked in.
const WALK_IN_MARGIN := 0.12
## A frame that holds the fixing player's own body where they stand (looking steeply down) takes them only once they
## have stepped this far from there.
const OWN_BODY_STEP := 0.25
## The heights of a standing player tried against the frame (metres above the feet); the eye's is among them, since
## close to the fixing eye the frame is only as tall as a head.
const BODY_HEIGHTS := [0.2, 0.6, 1.0, 1.4, 1.56, 1.7]

const STATE_NONE := ""
const STATE_PREVIEW := "preview"
const STATE_FIXED := "fixed"

var _state := STATE_NONE
var _flat := false
## The fixing eye, the frame it saw in tangents (position: left and bottom, end: right and top), and how far ahead of it
## a body counts as walked in.
var _eye := Transform3D.IDENTITY
var _tangents := Rect2()
var _enter_at := NEAR + WALK_IN_MARGIN
## Where the fixing player stood, when the frame held their own body there; else not finite.
var _own_ground := Vector3.INF
## Room space to the other world's.
var _to_other := Transform3D.IDENTITY
var _other_start := Transform3D.IDENTITY
var _viewport: SubViewport
var _other_camera: Camera3D
var _window: MeshInstance3D
var _material: ShaderMaterial


## Builds the window over `bounds` (the room, in this node's space) and the other world behind it. `other_start` is
## where a player enters the other world, standing on its ground and facing its door.
func build(bounds: AABB, other_start: Transform3D) -> bool:
	_other_start = other_start
	var scene := load(OTHER_WORLD_PATH) as PackedScene
	if scene == null:
		push_error("The portal's other world did not load: %s" % OTHER_WORLD_PATH)
		return false
	_viewport = SubViewport.new()
	_viewport.name = "PortalWorld"
	_viewport.own_world_3d = true
	_viewport.size = Vector2i(1200, 675)
	# The other world keeps its full range of light: the white door is far brighter than white, and a picture cut off
	# at white came out grey through the room's own tone mapping, then jumped to white on walking in.
	_viewport.use_hdr_2d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_viewport.add_child(scene.instantiate())
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.BLACK
	environment.ambient_light_energy = 0.0
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	# The room's own camera tone-maps the window with everything else; twice would crush it.
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)
	_other_camera = Camera3D.new()
	_other_camera.name = "PortalCamera"
	_viewport.add_child(_other_camera)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	# After the room's glass and anything else see-through: what lies in the frame is replaced, glass and all.
	_material.render_priority = RenderingServer.MATERIAL_RENDER_PRIORITY_MAX
	_material.set_shader_parameter("other_world", _viewport.get_texture())
	_material.set_shader_parameter("frame_near", NEAR)
	_material.set_shader_parameter("border", BORDER)
	# A box round the room, drawn from inside: the shader asks every pixel of the room whether the frame holds it.
	var box := BoxMesh.new()
	box.size = bounds.size + Vector3.ONE * 2.0
	_window = MeshInstance3D.new()
	_window.name = "PortalWindow"
	_window.mesh = box
	_window.position = bounds.get_center()
	_window.material_override = _material
	_window.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_window.extra_cull_margin = 16384.0
	_window.visible = false
	add_child(_window)
	return true


func state() -> String:
	return _state


func is_fixed() -> bool:
	return _state == STATE_FIXED


## Whether the fixed portal is a flat print (used up) and not a way through.
func is_flat() -> bool:
	return _flat


## The frame's part of the screen (0..1, y down) as tangents of a camera with this vertical field of view and aspect.
static func frame_tangents(frame: Rect2, fov_degrees: float, aspect: float) -> Rect2:
	var half_height := tan(deg_to_rad(fov_degrees) * 0.5)
	var half_width := half_height * aspect
	var left := (frame.position.x * 2.0 - 1.0) * half_width
	var right := (frame.end.x * 2.0 - 1.0) * half_width
	var top := (1.0 - frame.position.y * 2.0) * half_height
	var bottom := (1.0 - frame.end.y * 2.0) * half_height
	return Rect2(left, bottom, right - left, top - bottom)


## The X-ray looks through `tangents` of `eye` (this node's space) and has held still for `held` of the time it takes
## to fix (0..1): the other world shows in the frame, from `near` in front of the eye on, and the sticker is pasted that
## far round it. `floor_height` is the floor the looking player stands on. While a portal is fixed the look shows
## nothing new: the fixed one stays until another frame is fixed.
func look_through(eye: Transform3D, tangents: Rect2, held: float, floor_height: float = 0.0, near: float = NEAR) -> void:
	if _window == null or _state == STATE_FIXED:
		return
	_state = STATE_PREVIEW
	_place(eye, tangents, floor_height, near)
	_material.set_shader_parameter("progress", clampf(held, 0.0, 1.0))
	_material.set_shader_parameter("flat_picture", 0.0)
	_show(true)


## The X-ray looks away before the frame was fixed: nothing stays.
func look_away() -> void:
	if _state == STATE_PREVIEW:
		_state = STATE_NONE
		_show(false)


## The frame was held still long enough: it stays in the room as `eye` saw it, in place of any portal fixed before.
## `flat` fixes it as a print of the other world (a portal that is used up); `frame` is then the part of the screen the
## frame covered (0..1, y down). `feet` is where the fixing player stands (this node's space): the other world's ground
## is level with it, and that body does not count as walked in until it moves on. The other world begins `near` in front
## of the eye and a body counts as walked in from `enter_at` on: a host that knows a wall stands close gives both
## shorter, so a frame held up to a wall is pasted on it and walked into by walking at it.
func fix(eye: Transform3D, tangents: Rect2, flat: bool = false, frame: Rect2 = Rect2(0.0, 0.0, 1.0, 1.0), feet: Vector3 = Vector3.INF, near: float = NEAR, enter_at: float = NEAR + WALK_IN_MARGIN) -> void:
	if _window == null:
		return
	if _state == STATE_FIXED:
		clear()
	_state = STATE_FIXED
	_flat = flat
	_enter_at = enter_at
	_place(eye, tangents, feet.y if feet.is_finite() else 0.0, near)
	# Looking steeply down, the frame holds the fixing player's own legs: they have to take a step to walk in.
	_own_ground = feet if feet.is_finite() and _depth_held(feet) >= _enter_at else Vector3.INF
	_material.set_shader_parameter("progress", 1.0)
	_material.set_shader_parameter("flat_picture", 0.0)
	_show(true)
	if flat:
		_print_picture(frame)


## Takes the portal out of the room.
func clear() -> void:
	_state = STATE_NONE
	_flat = false
	if _window != null:
		_material.set_shader_parameter("other_world", _viewport.get_texture())
		_material.set_shader_parameter("flat_picture", 0.0)
		_show(false)


## Whether a player standing at `feet` (this node's space) is inside the fixed portal: far enough ahead of the fixing eye
## and inside the sticker, at any height of their body. Never for a flat print.
func holds(feet: Vector3) -> bool:
	if _state != STATE_FIXED or _flat:
		return false
	if _own_ground.is_finite() and Vector2(feet.x - _own_ground.x, feet.z - _own_ground.z).length() < OWN_BODY_STEP:
		return false
	return _depth_held(feet) >= _enter_at


## How far ahead of the fixing eye the deepest part of a body standing at `feet` lies inside the frame; negative when no
## part of it is inside.
func _depth_held(feet: Vector3) -> float:
	var to_eye := _eye.affine_inverse()
	var inside := _tangents.grow(-(BORDER * _tangents.size.y + 0.02))
	var deepest := -1.0
	for height: float in BODY_HEIGHTS:
		var seen := to_eye * (feet + Vector3(0.0, height, 0.0))
		var ahead := -seen.z
		if ahead > 0.05 and inside.has_point(Vector2(seen.x, seen.y) / ahead):
			deepest = maxf(deepest, ahead)
	return deepest


## The mapping from the room to the other world: where the player and their view go on walking in.
func to_other() -> Transform3D:
	return _to_other


func _place(eye: Transform3D, tangents: Rect2, floor_height: float, near: float) -> void:
	_eye = eye
	_tangents = tangents
	# The fixing player stands at the other world's start, looking the way its door lies, whatever their pitch.
	var heading := atan2(-eye.basis.z.x, -eye.basis.z.z)
	var on_floor := Transform3D(Basis(Vector3.UP, heading), Vector3(eye.origin.x, floor_height, eye.origin.z))
	var other_heading := atan2(-_other_start.basis.z.x, -_other_start.basis.z.z)
	var other_floor := Transform3D(Basis(Vector3.UP, other_heading), _other_start.origin)
	_to_other = other_floor * on_floor.affine_inverse()
	_material.set_shader_parameter("to_frame", (_room_to_world() * eye).affine_inverse())
	_material.set_shader_parameter("frame_tangents", Vector4(tangents.position.x, tangents.position.y, tangents.end.x, tangents.end.y))
	_material.set_shader_parameter("frame_near", near)


func _room_to_world() -> Transform3D:
	return global_transform if is_inside_tree() else transform


func _show(shown: bool) -> void:
	_window.visible = shown
	# A print (`_print_picture`) stops the other world's camera again once its picture is taken.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	if shown:
		_follow()


## A used-up portal keeps what the other world looked like from the fixing eye, as a still picture.
func _print_picture(frame: Rect2) -> void:
	var picture: Image = null
	if DisplayServer.get_name() != "headless":
		picture = _viewport.get_texture().get_image()
	if picture == null or picture.is_empty():
		# No picture could be taken (nothing was drawn yet): the window stays live but nobody walks in.
		return
	_material.set_shader_parameter("other_world", ImageTexture.create_from_image(picture))
	_material.set_shader_parameter("picture_rect", Vector4(frame.position.x, frame.position.y, frame.size.x, frame.size.y))
	_material.set_shader_parameter("flat_picture", 1.0)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _process(_delta: float) -> void:
	if _state != STATE_NONE and _window != null and _window.visible:
		_follow()


## The other world's camera stands where the player's camera does, taken through the mapping, and sees as it does.
func _follow() -> void:
	if not is_inside_tree():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# The screen in its own pixels (the interface may be laid out at another size than the window is drawn at).
	var screen_texture := get_viewport().get_texture()
	var screen := Vector2(screen_texture.get_size()) if screen_texture != null else get_viewport().get_visible_rect().size
	var wanted := Vector2i((screen * PICTURE_SCALE).round())
	if wanted.x > 0 and wanted.y > 0 and _viewport.size != wanted:
		_viewport.size = wanted
	var in_room := _room_to_world().affine_inverse() * camera.global_transform
	_other_camera.transform = _to_other * in_room
	_other_camera.fov = camera.fov
	_other_camera.near = camera.near
	_other_camera.far = maxf(camera.far, 200.0)
