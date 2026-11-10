extends SceneTree
const Layout = preload("res://maps/world_layout.gd")
var checks := 0
var failures: Array[String] = []
var square: Node2D
var player: CharacterBody2D

func _initialize() -> void:
	call_deferred("run_tests")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func settle(ticks: int = 3) -> void:
	for _i in ticks:
		await physics_frame
		await process_frame

func can_stand(point: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("Feet").shape
	query.transform = Transform2D(0, point + Vector2(0, -8))
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	return square.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func run_tests() -> void:
	root.size = Vector2i(1280, 896)
	square = load("res://maps/douar_square.tscn").instantiate()
	root.add_child(square)
	player = load("res://characters/player.tscn").instantiate()
	player.position = square.get_node("PlayerSpawn").position
	square.get_node("DepthSort").add_child(player)
	var camera: Camera2D = player.get_node("FollowCamera")
	camera.limit_right = Layout.SQUARE_SIZE.x
	camera.limit_bottom = Layout.SQUARE_SIZE.y
	await settle()
	var map_cells := Layout.SQUARE_SIZE / Layout.TILE_SIZE
	expect(square.get_node("Ground").get_used_cells().size() == map_cells.x * map_cells.y, "Square ground is incomplete")
	expect(square.get_meta("map_size_pixels") == Layout.SQUARE_SIZE, "Square dimensions disagree with camera/save bounds")
	expect(not square.has_node("AreaSign") and not square.has_node("DepthSort/Hanout") and not square.has_node("DepthSort/BreadOven"), "Old square signage, hanout or oven remains")
	for sign in [["Bakery/Name", "المخبزة"], ["ToFarm/Name", "الفيرمة"], ["Cafe/Artwork/Name", "القهوة"], ["Greengrocer/Artwork/Name", "مول الخضرة"]]:
		var label: Label = square.get_node("DepthSort/" + sign[0])
		expect(label.text == sign[1], "New shop sign is not localized: " + sign[0])
		var text_width := label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		expect(text_width <= label.size.x and label.get_visible_line_count() >= label.get_line_count(), "New shop sign is clipped: " + sign[0])
	var player_home_copies := 0
	for body in square.get_node("DepthSort").get_children():
		var artwork: Sprite2D = body.get_node_or_null("Artwork")
		if body.get_meta("pattern", "") == "farmhouse":
			player_home_copies += 1
		elif artwork != null and artwork.texture is AtlasTexture:
			var texture: AtlasTexture = artwork.texture
			if texture.atlas.resource_path == "res://assets/tilesets/buildings.png" and texture.region.intersects(Rect2(0, 0, 256, 224)):
				player_home_copies += 1
	expect(player_home_copies == 0, "The player's unique farmhouse was duplicated in the village")
	var blue: Sprite2D = square.get_node("DepthSort/NeighborBlue/Artwork")
	var earth: Sprite2D = square.get_node("DepthSort/NeighborEarth/Artwork")
	expect(blue.texture.resource_path != earth.texture.resource_path, "Neighbor houses reuse the same artwork")
	expect(can_stand(player.position), "Square spawn overlaps an obstacle")
	expect(not can_stand(Vector2(-8, Layout.SQUARE_SPAWN.y)), "Square has no western boundary")
	for name_ in ["Bakery", "NeighborBlue", "NeighborEarth", "Cafe", "Greengrocer", "Well", "Fountain"]:
		var body: StaticBody2D = square.get_node("DepthSort/" + name_)
		var footprint: Rect2 = body.get_meta("footprint_local")
		expect(not can_stand(body.position + footprint.get_center() + Vector2(0, 8)), "Landmark has no solid footprint: " + name_)
	for point in [Vector2(112, 384), Vector2(112, 416), Vector2(160, 416)]:
		expect(can_stand(point), "Removed oven still blocks walking: " + str(point))
	var route: StaticBody2D = square.get_node("DepthSort/ToFarm")
	expect(route.get_node("Artwork").flip_h, "Farm sign points away from the western exit")
	expect(not can_stand(route.position + Vector2(0, 8)), "Sign post has no solid base")
	expect(can_stand(route.position + Vector2(32, 8)), "Sign board blocks the path beside its post")
	expect(not can_stand(Vector2(400, 864)) and not can_stand(Vector2(1000, 864)), "Unbridged village saqya is walkable")
	expect(can_stand(Vector2(656, 864)), "Village footbridge is blocked")
	# Real player-sized physics queries must reach every entrance and the bridge.
	var targets: Dictionary = {}
	for point in [Vector2i(208, 336), Vector2i(448, 336), Vector2i(992, 304), Vector2i(144, 816), Vector2i(960, 784), Vector2i(1136, 448), Vector2i(640, 560), Vector2i(656, 880), Vector2i(32, 496)]:
		targets[point / 16] = true
	var start := Vector2i(Layout.SQUARE_SPAWN) / 16
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var grid_size := Layout.SQUARE_SIZE / 16
	var index := 0
	while index < queue.size() and not targets.is_empty():
		var cell := queue[index]
		index += 1
		targets.erase(cell)
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + offset
			if next.x < 1 or next.y < 1 or next.x >= grid_size.x or next.y >= grid_size.y or seen.has(next):
				continue
			seen[next] = true
			if can_stand(Vector2(next * 16)):
				queue.append(next)
	expect(targets.is_empty(), "Square landmarks are not connected: " + str(targets.keys()))
	Input.action_press("move_right")
	await settle(90)
	Input.action_release("move_right")
	await settle()
	expect(player.position.x > 300, "Western approach blocks walking into the square")
	square.queue_free()
	await settle()
	print("Douar square: %d checks, %d failures." % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
