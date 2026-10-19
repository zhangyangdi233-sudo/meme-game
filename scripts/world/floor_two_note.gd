extends Area3D
## A small physical paper; main owns F interaction, visibility and persistence.

const Paper = preload("res://scripts/ui/floor_two_note_paper.gd")
const PAPER_SIZE := Vector2(0.52, 0.325)

func _init() -> void:
	name = "FloorTwoNote"
	set_meta("actor_type", "floor2_note")
	set_meta("actor_id", "floor2_note")
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	input_ray_pickable = true

func _ready() -> void:
	var texture_view := SubViewport.new()
	texture_view.name = "PaperTexture"
	texture_view.size = Vector2i(1024, 640)
	texture_view.disable_3d = true
	texture_view.transparent_bg = true
	texture_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(texture_view)
	var paper := Paper.new()
	paper.size = Vector2(texture_view.size)
	texture_view.add_child(paper)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture_view.get_texture()
	material.roughness = 1.0
	material.emission_enabled = false
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	var mesh := MeshInstance3D.new()
	mesh.name = "PaperMesh"
	var quad := QuadMesh.new()
	quad.size = PAPER_SIZE
	mesh.mesh = quad
	mesh.material_override = material
	mesh.position.y = 0.035
	mesh.rotation_degrees = Vector3(-90, -13, 0)
	add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.name = "InteractionArea"
	var box := BoxShape3D.new()
	box.size = Vector3(0.72, 0.18, 0.52)
	shape.shape = box
	shape.position.y = 0.07
	add_child(shape)
