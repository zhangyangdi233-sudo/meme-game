class_name VhsOverlay
extends Control
## Full-screen VHS post-process: back-buffer capture plus shader filter. Intensity and
## distortion are supplied each frame by the game adapter (no domain snapshot here).
## The filter's lens bows the picture only while the host says the pointer is captured (`set_lens_bowed`): under a free
## pointer a bowed picture would show the terminal's words and the menus' buttons away from where a click lands. The bow
## eases in and out.

const SHADER_PATH := "res://shaders/vhs_screen.gdshader"
# Old version's tuned default; 0.62 tore text too hard once the overlay actually drew.
const DEFAULT_INTENSITY := 0.46
const DISTORTION_SHADER_PARAM := "poll" + "ution"
const LENS_BOW_SHADER_PARAM := "lens_bow"
const LENS_BOW_SECONDS := 0.35

var _shader_rect: ColorRect
## Whether the lens should bow now, and how far it has eased there (0 flat, 1 bowed).
var _lens_bowed := false
var _lens_bow := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# set_anchors_preset alone keeps the 0x0 rect once in the tree, so the filter never drew.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ensure_nodes()


func configure(intensity: float, distortion: float) -> void:
	_ensure_nodes()
	modulate.a = 1.0
	var material := _shader_rect.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter(DISTORTION_SHADER_PARAM, distortion)


## The host says whether the pointer is captured (the player walks and looks): the lens bows only then.
func set_lens_bowed(bowed: bool) -> void:
	_lens_bowed = bowed


func is_lens_bowed() -> bool:
	return _lens_bowed


## How far the lens is bowed right now: 0 flat, 1 fully bowed.
func lens_bow() -> float:
	return _lens_bow


func _process(delta: float) -> void:
	var target := 1.0 if _lens_bowed else 0.0
	if _shader_rect == null or is_equal_approx(_lens_bow, target):
		return
	_lens_bow = move_toward(_lens_bow, target, maxf(delta, 0.0) / LENS_BOW_SECONDS)
	(_shader_rect.material as ShaderMaterial).set_shader_parameter(LENS_BOW_SHADER_PARAM, _lens_bow)


func _ensure_nodes() -> void:
	if _shader_rect != null:
		return

	var back_buffer := BackBufferCopy.new()
	back_buffer.name = "VHSBackBufferCopy"
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(back_buffer)

	_shader_rect = ColorRect.new()
	_shader_rect.name = "VHSDynamicFilter"
	_shader_rect.color = Color.WHITE
	# Offsets too, so the filter covers the overlay whatever size it has when built.
	_shader_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load(SHADER_PATH) as Shader
	shader_material.set_shader_parameter("intensity", DEFAULT_INTENSITY)
	shader_material.set_shader_parameter(DISTORTION_SHADER_PARAM, 0.0)
	shader_material.set_shader_parameter(LENS_BOW_SHADER_PARAM, _lens_bow)
	_shader_rect.material = shader_material
	add_child(_shader_rect)
