extends SceneTree
## Original procedural maps. Run with --headless --script to rebuild; no downloaded art.

const OUTPUT := "res://assets/chapter1/atmosphere"
const SIZE := 256

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	_surface("aged_wall", false)
	_surface("woven_carpet", true)
	_stain()
	print("basement atmosphere textures generated")
	quit()

func _surface(prefix: String, carpet: bool) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 4719 if carpet else 8510
	noise.frequency = 0.021 if carpet else 0.038
	var base := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var normal := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var rough := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var heights := PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var grain := sin(float(x * 73 + y * 137)) * 0.5 + 0.5
			var cloudy := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var weave := float((x + (y / 3 % 2)) % 3 == 0 or y % 3 == 0)
			var value := cloudy * 0.65 + grain * 0.2 + weave * 0.15
			var color: Color
			if carpet:
				color = Color("26382B").lerp(Color("677057"), value * 0.78)
				heights[y * SIZE + x] = weave * 0.55 + grain * 0.16
			else:
				var faded_patch := smoothstep(0.51, 0.69, cloudy)
				color = Color("4C6750").lerp(Color("64775A"), value * 0.52)
				color = color.lerp(Color("879175"), faded_patch * 0.08)
				# Papery grain and subtle 1 m seam; major damage is a separate decal.
				if x < 2:
					color *= 0.7
				heights[y * SIZE + x] = grain * 0.018 + weave * 0.012 + cloudy * 0.025 + faded_patch * 0.008
			base.set_pixel(x, y, color)
			rough.set_pixel(x, y, Color(0.86 + grain * 0.12, 0.86 + grain * 0.12, 0.86 + grain * 0.12))
	for y in SIZE:
		for x in SIZE:
			var dx := heights[y * SIZE + (x + 1) % SIZE] - heights[y * SIZE + (x + SIZE - 1) % SIZE]
			var dy := heights[((y + 1) % SIZE) * SIZE + x] - heights[((y + SIZE - 1) % SIZE) * SIZE + x]
			var n := Vector3(-dx * 2.8, dy * 2.8, 1.0).normalized()
			normal.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	base.save_png(OUTPUT.path_join(prefix + "_albedo.png"))
	normal.save_png(OUTPUT.path_join(prefix + "_normal.png"))
	rough.save_png(OUTPUT.path_join(prefix + "_roughness.png"))

func _stain() -> void:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 31579
	noise.frequency = 0.038
	for y in SIZE:
		for x in SIZE:
			var edge := sin(PI * float(x) / SIZE) * sin(PI * float(y) / SIZE)
			var cloud := noise.get_noise_2d(float(x) * 1.8, float(y) * 0.45) * 0.5 + 0.5
			var drip := maxf(0, sin(float(x) * 0.32 + sin(float(y) * 0.021)))
			var alpha := smoothstep(0.45, 0.7, cloud) * edge * (0.25 + 0.35 * drip)
			image.set_pixel(x, y, Color(0.14, 0.17, 0.1, alpha))
	# Broken hairline plaster crack; tiny forks share a single transparent atlas.
	var rng := RandomNumberGenerator.new()
	rng.seed = 94
	var point := Vector2i(99, 26)
	for step in 39:
		var next := point + Vector2i(rng.randi_range(-5, 6), rng.randi_range(3, 5))
		_line(image, point, next, Color(0.12, 0.14, 0.1, 0.58))
		if step % 9 == 0:
			_line(image, point, point + Vector2i(rng.randi_range(12, 24), -12), Color(0.12, 0.14, 0.1, 0.35))
		point = next
	image.save_png(OUTPUT.path_join("damp_crack_decal.png"))

func _line(image: Image, start: Vector2i, end: Vector2i, color: Color) -> void:
	var steps := maxi(absi(end.x - start.x), absi(end.y - start.y))
	for i in steps + 1:
		var at := Vector2(start).lerp(Vector2(end), float(i) / maxf(1.0, steps))
		if at.x >= 0 and at.y >= 0 and at.x < SIZE and at.y < SIZE:
			image.set_pixel(int(at.x), int(at.y), color)
