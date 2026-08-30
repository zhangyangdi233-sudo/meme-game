class_name VhsOverlay
extends Control
## Full-screen VHS post-process: back-buffer capture plus shader filter. Intensity and
## distortion are supplied each frame by the game adapter (no domain snapshot here).

const SHADER_PATH := "res://shaders/vhs_screen.gdshader"
const DEFAULT_INTENSITY := 0.62
const DISTORTION_SHADER_PARAM := "poll" + "ution"

var _shader_rect: ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_ensure_nodes()


func configure(intensity: float, distortion: float) -> void:
	_ensure_nodes()
	modulate.a = 1.0
	var material := _shader_rect.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("intensity", intensity)
	material.set_shader_parameter(DISTORTION_SHADER_PARAM, distortion)


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
	_shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load(SHADER_PATH) as Shader
	shader_material.set_shader_parameter("intensity", DEFAULT_INTENSITY)
	shader_material.set_shader_parameter(DISTORTION_SHADER_PARAM, 0.0)
	_shader_rect.material = shader_material
	add_child(_shader_rect)
