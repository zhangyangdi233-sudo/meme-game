class_name CrtScreen
extends RefCounted
## The basement CRT's glass: one imported mesh surface the terminal display is shown on. It answers where the glass
## is, which way it faces, and where a ray meets it as a 0..1 UV (top-left origin), from the mesh's own triangles.
## The VHS look on the glass is its own setting.

const SHADER := preload("res://shaders/crt_terminal.gdshader")
## A ray that meets no glass.
const MISS := Vector2(-1, -1)

var _mesh: MeshInstance3D
var _triangles: Array[Dictionary] = []
var _material: ShaderMaterial


## Binds the glass; false when the mesh has no surface with UVs to show a display on.
func bind(mesh: MeshInstance3D) -> bool:
	if mesh == null or mesh.mesh == null or mesh.mesh.get_surface_count() == 0:
		return false
	_triangles = _read_triangles(mesh.mesh)
	if _triangles.is_empty():
		return false
	_mesh = mesh
	return true


## The glass's middle in world space.
func center() -> Vector3:
	return _mesh.global_transform * _mesh.get_aabb().get_center()


## The direction the glass faces, level with the floor.
func forward() -> Vector3:
	var facing := _mesh.global_basis * Vector3.BACK
	facing.y = 0.0
	return facing.normalized()


## The glass's height in world space.
func height() -> float:
	return (_mesh.global_transform * _mesh.get_aabb()).size.y


## Shows `texture` on the glass with or without the VHS look.
func show_display(texture: Texture2D, vhs_enabled: bool) -> void:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
		_mesh.set_surface_override_material(0, _material)
	_material.set_shader_parameter("content_texture", texture)
	_material.set_shader_parameter("vhs_enabled", vhs_enabled)


## Where a world-space ray meets the glass, as a UV with its origin at the top left; `MISS` when it does not.
func uv_at(origin: Vector3, direction: Vector3) -> Vector2:
	var to_local := _mesh.global_transform.affine_inverse()
	var local_origin := to_local * origin
	var local_direction := to_local.basis * direction
	var nearest := INF
	var hit := MISS
	for triangle in _triangles:
		var found := _triangle_hit(local_origin, local_direction, triangle)
		if not found.is_empty() and float(found["distance"]) < nearest:
			nearest = float(found["distance"])
			hit = found["uv"]
	return hit


func _read_triangles(mesh: Mesh) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var arrays := mesh.surface_get_arrays(0)
	if arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_TEX_UV] == null:
		return result
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices := PackedInt32Array()
	if arrays[Mesh.ARRAY_INDEX] != null:
		indices = arrays[Mesh.ARRAY_INDEX]
	else:
		for index in vertices.size():
			indices.append(index)
	for offset in range(0, indices.size() - 2, 3):
		var a := indices[offset]
		var b := indices[offset + 1]
		var c := indices[offset + 2]
		# A triangle with no UV area (the glass's rim) cannot place a point on the display.
		if absf((uvs[b] - uvs[a]).cross(uvs[c] - uvs[a])) < 0.000001:
			continue
		result.append({"a": vertices[a], "b": vertices[b], "c": vertices[c], "uv_a": uvs[a], "uv_b": uvs[b], "uv_c": uvs[c]})
	return result


## Möller–Trumbore: the distance along the ray and the UV where it crosses one triangle.
func _triangle_hit(origin: Vector3, direction: Vector3, triangle: Dictionary) -> Dictionary:
	var edge_b: Vector3 = triangle["b"] - triangle["a"]
	var edge_c: Vector3 = triangle["c"] - triangle["a"]
	var p := direction.cross(edge_c)
	var determinant := edge_b.dot(p)
	if absf(determinant) < 0.0000001:
		return {}
	var offset: Vector3 = origin - triangle["a"]
	var u := offset.dot(p) / determinant
	var q := offset.cross(edge_b)
	var v := direction.dot(q) / determinant
	var distance := edge_c.dot(q) / determinant
	if distance < 0.0 or u < 0.0 or v < 0.0 or u + v > 1.0:
		return {}
	var uv: Vector2 = triangle["uv_a"] * (1.0 - u - v) + triangle["uv_b"] * u + triangle["uv_c"] * v
	return {"distance": distance, "uv": uv}
